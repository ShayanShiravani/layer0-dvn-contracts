// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMRC721} from "./interfaces/IMRC721.sol";

/**
 * @title ERC721MinterOApp Contract
 * @dev ERC721MinterOApp is considered to create a minter .
 */
contract ERC721MinterOApp is OApp {
    IMRC721 public token;

    event NFTSent(
        uint32 indexed dstEid,
        address indexed from,
        uint256 indexed tokenId,
        bytes payload
    );
    event NFTReceived(
        uint32 indexed srcEid,
        bytes32 indexed sender,
        bytes payload,
        address executor,
        bytes extraData
    );

    constructor(
        address _endpoint,
        address _owner,
        address _token
    ) OApp(_endpoint, _owner) Ownable(_owner) {
        token = IMRC721(_token);
    }

    // Sends a message from the source to destination chain.
    function send(
        uint32 _dstEid,
        address _from,
        uint256 _tokenId,
        MessagingFee calldata _fee,
        bytes calldata _options
    ) external payable {
        bytes memory payload = token.burnFrom(_from, _tokenId);
        _lzSend(
            _dstEid, // Destination chain's endpoint ID.
            payload, // Encoded message payload being sent.
            _options, // Message execution options (e.g., gas to use on destination).
            _fee, // Fee struct containing native gas and ZRO token.
            payable(msg.sender) // The refund address in case the send call reverts.
        );
        emit NFTSent(_dstEid, _from, _tokenId, payload);
    }

    /* @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(
        uint32 _dstEid, // Destination chain's endpoint ID.
        address _from,
        uint256 _tokenId,
        bytes calldata _options, // Message execution options
        bool _payInLzToken // boolean for which token to return fee in
    ) public returns (uint256 nativeFee, uint256 lzTokenFee) {
        bytes memory _payload = token.encodeParams(_from, _tokenId);
        MessagingFee memory fee = _quote(
            _dstEid,
            _payload,
            _options,
            _payInLzToken
        );
        return (fee.nativeFee, fee.lzTokenFee);
    }

    function _lzReceive(
        Origin calldata _origin, // struct containing info about the message sender
        bytes32, // global packet identifier
        bytes calldata _payload, // encoded message payload being received
        address _executor, // the Executor address.
        bytes calldata _extraData // arbitrary data appended by the Executor
    ) internal override {
        token.mintTo(_payload);
        emit NFTReceived(
            _origin.srcEid,
            _origin.sender,
            _payload,
            _executor,
            _extraData
        );
    }
}
