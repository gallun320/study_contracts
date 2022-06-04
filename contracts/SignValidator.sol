//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract SignValidator { 
    string private constant _prefix = "\x19Ethereum Signed Message:\n32";
    uint256 private constant _signLength = 65;

    error SignIsIncorrect();

    function getMessageHash(
        address to,
        uint256 amount,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(to, amount, nonce));
    }

    function getEthSignedMessageHash(bytes32 messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(_prefix, messageHash)
            );
    }


    function verify(
        address signer,
        address to,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) internal pure returns (bool) {
        bytes32 messageHash = getMessageHash(to, amount, nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes calldata signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        if(sig.length != _signLength) {
            revert SignIsIncorrect();
        }

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (r,s,v);
    }

}