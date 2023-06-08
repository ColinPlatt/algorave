// SPDX-License-Identifier: The Unlicense
pragma solidity ^0.8.19;

import "lib/solady/src/utils/LibZip.sol";

contract TrackRegister {

    struct SoundBiteInstruction {
        bytes32 id;
        bytes data; // should be the fully abi.encodeWithSignature(signatureString, arg) for the soundbite, for SSTORE it should be blank
        uint32 startTime; // samples are 22050 per second, so max is ~194783 seconds
        uint16 duration;
        
    }

    struct Track {
        string name;
        SoundBiteInstruction[] instructions;
    }

    mapping(bytes32 => Track) public tracks;

}