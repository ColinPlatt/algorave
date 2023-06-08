// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.19;

import "lib/solady/src/utils/SSTORE2.sol";

contract SoundLibrary {

    ///* This library is a repository for onchain wav files, and allows anyone to link sound files which can be called by an identifier hash, and linked into a track.

    // soundBites can either be an array of SSTORE2 addresses which are read sequentially, or a single contract address which is read depending on provided input.
    struct SoundBite{
        address[] pointers;
        bool isCompressed;
    }
    
    mapping(bytes32 => SoundBite) public soundBites;

    error SoundBiteNotFound(bytes32 id);
    error SoundBiteExists(bytes32 id);
    error SoundBiteTooLong(uint256 length);
    error SoundBiteStaticcallFailed(bytes32 id);

    event NewSoundBite(bytes32 id, bool isCompressed);

    /*//////////////////////////////////////////////////////////////
                       STORE AND LIST SOUNDBITES
    //////////////////////////////////////////////////////////////*/

    // list a single address soundbite to the library (usually for smart contract based soundbites), and set isCompressed to false
    function listSoundBite(address newSoundBite) public {
        bytes32 id = keccak256(abi.encodePacked(newSoundBite));

        if(soundBites[id].pointers.length != 0) {
            revert SoundBiteExists(id);
        }

        address[] memory newSoundBiteArray = new address[](1);

        soundBites[id].pointers = newSoundBiteArray;
        soundBites[id].isCompressed = false;

        emit NewSoundBite(id, false);
    }

    // list a multipart soundbite to the library (usually SSTORE2 based soundbites), allows to specify if the soundbite components are compressed or not
    function listSoundBite(address[] memory newSoundBite, bool compressed) public {
        bytes32 id = keccak256(abi.encodePacked(newSoundBite));

        if(soundBites[id].pointers.length != 0) {
            revert SoundBiteExists(id);
        }

        soundBites[id].pointers = newSoundBite;
        soundBites[id].isCompressed = compressed;

        emit NewSoundBite(id, compressed);
    }

    // This allows the user to store a piece of audio in an SSTORE2 contract, and returns the pointer.
    function storeSoundBite(bytes calldata data) public returns (address) {
        
        if(data.length > 24000) {
            revert SoundBiteTooLong(data.length);
        }

        return SSTORE2.write(data);
    }

    function storeSoundBite(bytes[] calldata data) public returns (address[] memory) {
        
        address[] memory pointers = new address[](data.length);

        unchecked {
            for(uint256 i = 0; i < data.length; i++) {
                if(data[i].length > 24000) {
                    revert SoundBiteTooLong(data[i].length);
                }
                pointers[i] = SSTORE2.write(data[i]);
            }
        }
        return pointers;
    }

    /*//////////////////////////////////////////////////////////////
                       RETRIEVE SOUNDBITES
    //////////////////////////////////////////////////////////////*/

    // This function returns the bytes of a soundbite, and is used by the track contract to retrieve the soundbite.
    // Adapted from https://gist.github.com/xtremetom/20411eb126aaf35f98c8a8ffa00123cd
    function getSoundBite(bytes32 identifier) public view returns (bytes memory o_code, bool isCompressed) {
        if(soundBites[identifier].pointers.length == 0) {
            revert SoundBiteNotFound(identifier);
        }

        address[] memory chunks = soundBites[identifier].pointers;

        unchecked {
            assembly {
                let len := mload(chunks)
                let totalSize := 0x20
                let size := 0
                o_code := mload(0x40)

                // loop through all chunk addresses
                // - get address
                // - get data size
                // - get code and add to o_code
                // - update total size
                let targetChunk := 0
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    targetChunk := mload(add(chunks, add(0x20, mul(i, 0x20))))
                    size := sub(extcodesize(targetChunk), 1)
                    extcodecopy(targetChunk, add(o_code, totalSize), 1, size)
                    totalSize := add(totalSize, size)
                }

                // update o_code size
                mstore(o_code, sub(totalSize, 0x20))
                // store o_code
                mstore(0x40, add(o_code, and(add(totalSize, 0x1f), not(0x1f))))
            }
        }

        isCompressed = soundBites[identifier].isCompressed;
    }

    // This function returns the bytes of a contract based soundbite by using a static call, and is used by the track contract to retrieve the soundbite.
    function getSoundBite(bytes32 identifier, bytes memory data) public view returns (bytes memory) {
        if(soundBites[identifier].pointers.length != 1) {
            revert SoundBiteNotFound(identifier);
        }

        address target = soundBites[identifier].pointers[0];

        (bool success, bytes memory o_code) = target.staticcall(data);

        if(!success) {
            revert SoundBiteStaticcallFailed(identifier);
        }

        return o_code;
    }
}