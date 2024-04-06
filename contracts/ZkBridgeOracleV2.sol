// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "../interface/IBlockUpdater.sol";
// import "../interface/IZKMptValidator.sol";
// import "../interface/IMptValidator.sol";
// import "../libraries/RLPReader.sol";
// import "contracts/libraries/LzV2PacketCodec.sol";
// import {ILayerZeroEndpointV2} from "../interface/layerzeroV2/ILayerZeroEndpointV2.sol";
// import {ILayerZeroDVN} from "../interface/layerzeroV2/ILayerZeroDVN.sol";
// import {IReceiveUlnE2, Verification, UlnConfig} from "../interface/layerzeroV2/IReceiveUlnE2.sol";
// import {IReceiveUlnView, VerificationState} from "../interface/layerzeroV2/IReceiveUlnView.sol";
// import {ISendLib, MessageLibType} from "../interface/layerzeroV2/ISendLib.sol";
// import {ILayerZeroEndpoint} from "../interface/ILayerZeroEndpoint.sol";

// contract ZkBridgeOracleV2 is ILayerZeroDVN, Initializable, OwnableUpgradeable {
//     using LzV2PacketCodec for bytes;
//     using RLPReader for RLPReader.RLPItem;
//     using RLPReader for bytes;

//     struct MessageLibInfo {
//         bool enabled;
//         MessageLibType libType;
//         address lib;
//     }

//     bytes32 public constant MESSAGE_TOPIC_V1 =
//         0x3dc6f2ede34d1db05729bbb76e5efd17ec1bc83f98f665e7fba0596dca438b96;
//     bytes32 public constant MESSAGE_TOPIC_V2 =
//         0x1ab700d4ced0c005b164c0f789fd09fcbb0156d4c2041b8a3bfbcd961cd1567f;

//     ILayerZeroEndpointV2 public immutable layerZeroEndpointV2;
//     ILayerZeroEndpoint public immutable layerZeroEndpointV1;
//     uint32 public immutable localEid;

//     // eid=>fee
//     mapping(uint32 => uint256) public chainFeeLookup;
//     // eid=>bool
//     mapping(uint32 => bool) public supportedDstChain;
//     // eid=>blockUpdater
//     mapping(uint32 => IBlockUpdater) public blockUpdaters;

//     IZKMptValidator public zkMptValidator;

//     IMptValidator public mptValidator;

//     address[] internal lzMessageLibs;

//     mapping(address => MessageLibInfo) internal messageLibLookup;

//     mapping(address => bool) public feeManager;

//     mapping(address => address) public receiveLibToView;

//     mapping(uint32 => address) public trustedRemoteLookup;

//     event OracleNotified(
//         uint32 dstEid,
//         uint64 blockConfirmations,
//         address userApplication,
//         uint256 fee
//     );
//     event WithdrawFee(address messageLib, address receiver, uint256 amount);
//     event SetFee(uint32 dstEid, uint256 fee);
//     event NewBlockUpdater(
//         uint32 srcEid,
//         address oldBlockUpdater,
//         address newBlockUpdater
//     );
//     event NewZKMptValidator(address oldValidator, address newValidator);
//     event NewMptValidator(address oldValidator, address newValidator);
//     event DstChainStatusChanged(uint32 dstEid, bool enabled);
//     event SetFeeManager(address feeManager, bool enabled);

//     error ZeroAddress();
//     error ZkMptValidatorUnavailable();
//     error MptValidatorUnavailable();
//     error NotTrustedSource();
//     error UnsupportedUpdater(uint32 srcEid);
//     error UnsupportedChain(uint32 dstEid);
//     error UnsupportedSendLib();
//     error BlockNotSet();
//     error OnlySendLib();
//     error InsufficientFee();
//     error MessageLibAlreadyAdded();
//     error MessageLibAlreadyDeleted();
//     error AlreadySet();
//     error Unauthorized();
//     error InvalidZkMptProof();
//     error InvalidParameters();
//     error ReceiveLibViewNotSet();
//     error PacketNotVerified();

//     modifier onlyFeeManager() {
//         if (!feeManager[msg.sender]) revert Unauthorized();
//         _;
//     }

//     constructor(address _layerZeroEndpointV2, address _layerZeroEndpointV1) {
//         if (_layerZeroEndpointV2 == address(0)) revert ZeroAddress();
//         if (_layerZeroEndpointV1 == address(0)) revert ZeroAddress();
//         layerZeroEndpointV2 = ILayerZeroEndpointV2(_layerZeroEndpointV2);
//         layerZeroEndpointV1 = ILayerZeroEndpoint(_layerZeroEndpointV1);
//         localEid = layerZeroEndpointV2.eid();
//         _disableInitializers();
//     }

//     function initialize() public initializer {
//         feeManager[msg.sender] = true;
//         __Ownable_init();
//     }

//     function batchVerify(
//         bytes32[] calldata _blockHashs,
//         bytes[] calldata _encodedPayloads,
//         bytes[] calldata _zkMptProof
//     ) external {
//         if (address(zkMptValidator) == address(0))
//             revert ZkMptValidatorUnavailable();
//         if (
//             _blockHashs.length != _encodedPayloads.length ||
//             _blockHashs.length != _zkMptProof.length
//         ) {
//             revert InvalidParameters();
//         }

//         IZKMptValidator.Receipt memory receipt;
//         for (uint256 i = 0; i < _blockHashs.length; i++) {
//             receipt = zkMptValidator.validateMPT(_zkMptProof[i]);
//             if (keccak256(_encodedPayloads[i]) != receipt.logsHash)
//                 revert InvalidZkMptProof();
//             _verify(
//                 _blockHashs[i],
//                 receipt.receiptHash,
//                 _encodedPayloads[i].srcEid(),
//                 _encodedPayloads[i].receiver(),
//                 _encodedPayloads[i].header(),
//                 _encodedPayloads[i].payloadHash()
//             );
//         }
//     }

//     function batchVerifyByMpt(
//         bytes32[] calldata _blockHashs,
//         uint256[] calldata _logIndex,
//         bytes[] calldata _mptProof
//     ) external {
//         if (address(mptValidator) == address(0))
//             revert ZkMptValidatorUnavailable();
//         if (
//             _blockHashs.length != _logIndex.length ||
//             _blockHashs.length != _mptProof.length
//         ) {
//             revert InvalidParameters();
//         }

//         IMptValidator.Receipt memory receipt;
//         address logContract;
//         bytes memory encodedPayload;
//         uint32 srcEid;
//         for (uint256 i = 0; i < _blockHashs.length; i++) {
//             receipt = mptValidator.validateMPT(_mptProof[i]);
//             (logContract, encodedPayload) = _parseLog(
//                 receipt.logs,
//                 _logIndex[i]
//             );
//             if (logContract == address(0)) revert NotTrustedSource();

//             srcEid = encodedPayload.srcEid2();
//             if (_isV2(srcEid)) {
//                 if (logContract != address(layerZeroEndpointV2))
//                     revert NotTrustedSource();
//             } else {
//                 if (logContract != trustedRemoteLookup[srcEid])
//                     revert NotTrustedSource();
//             }

//             _verify(
//                 _blockHashs[i],
//                 receipt.receiptHash,
//                 srcEid,
//                 encodedPayload.receiver2(),
//                 encodedPayload.header2(),
//                 encodedPayload.payloadHash2()
//             );
//         }
//     }

//     function verify(
//         bytes32 _blockHash,
//         bytes calldata _encodedPayload,
//         bytes calldata _zkMptProof
//     ) external {
//         if (address(zkMptValidator) == address(0))
//             revert ZkMptValidatorUnavailable();
//         IZKMptValidator.Receipt memory receipt = zkMptValidator.validateMPT(
//             _zkMptProof
//         );
//         if (keccak256(_encodedPayload) != receipt.logsHash)
//             revert InvalidZkMptProof();

//         _verify(
//             _blockHash,
//             receipt.receiptHash,
//             _encodedPayload.srcEid(),
//             _encodedPayload.receiver(),
//             _encodedPayload.header(),
//             _encodedPayload.payloadHash()
//         );
//     }

//     function verifyByMpt(
//         bytes32 _blockHash,
//         uint256 _logIndex,
//         bytes calldata _mptProof
//     ) external {
//         if (address(mptValidator) == address(0))
//             revert MptValidatorUnavailable();
//         IMptValidator.Receipt memory receipt = mptValidator.validateMPT(
//             _mptProof
//         );
//         (address logContract, bytes memory encodedPayload) = _parseLog(
//             receipt.logs,
//             _logIndex
//         );
//         if (logContract == address(0)) revert NotTrustedSource();

//         uint32 srcEid = encodedPayload.srcEid2();
//         if (_isV2(srcEid)) {
//             if (logContract != address(layerZeroEndpointV2))
//                 revert NotTrustedSource();
//         } else {
//             if (logContract != trustedRemoteLookup[srcEid])
//                 revert NotTrustedSource();
//         }

//         _verify(
//             _blockHash,
//             receipt.receiptHash,
//             srcEid,
//             encodedPayload.receiver2(),
//             encodedPayload.header2(),
//             encodedPayload.payloadHash2()
//         );
//     }

//     function _parseLog(
//         bytes memory _logsByte,
//         uint256 _logIndex
//     ) internal pure returns (address logContract, bytes memory encodedPayload) {
//         RLPReader.RLPItem[] memory logs = _logsByte
//             .toRlpItem()
//             .listIndex(_logIndex)
//             .toList();
//         RLPReader.RLPItem[] memory topicItem = logs[1].toList();
//         bytes32 topic = bytes32(topicItem[0].toUint());
//         if (topic == MESSAGE_TOPIC_V1) {
//             logContract = logs[0].toAddress();
//             (encodedPayload, , , ) = abi.decode(
//                 logs[2].toBytes(),
//                 (bytes, bytes, uint256, uint256)
//             );
//         } else if (topic == MESSAGE_TOPIC_V2) {
//             logContract = logs[0].toAddress();
//             (encodedPayload, , ) = abi.decode(
//                 logs[2].toBytes(),
//                 (bytes, bytes, address)
//             );
//         }
//     }

//     /// @dev for dvn to verify the payload
//     function _verify(
//         bytes32 _blockHash,
//         bytes32 _receiptHash,
//         uint32 _srcEid,
//         address _receiver,
//         bytes memory _packetHeader,
//         bytes32 _payloadHash
//     ) internal {
//         IBlockUpdater blockUpdater = blockUpdaters[_srcEid];
//         if (address(blockUpdater) == address(0))
//             revert UnsupportedUpdater(_srcEid);
//         (bool exist, uint256 blockConfirmation) = blockUpdater
//             .checkBlockConfirmation(_blockHash, _receiptHash);
//         if (!exist) revert BlockNotSet();
//         address receiverLib;
//         if (_isV2(_srcEid)) {
//             (receiverLib, ) = layerZeroEndpointV2.getReceiveLibrary(
//                 _receiver,
//                 _srcEid
//             );
//         } else {
//             receiverLib = layerZeroEndpointV1.getReceiveLibraryAddress(
//                 _receiver
//             );
//         }
//         UlnConfig memory ulnConfig = IReceiveUlnE2(receiverLib).getUlnConfig(
//             _receiver,
//             _srcEid
//         );
//         if (blockConfirmation < ulnConfig.confirmations)
//             revert PacketNotVerified();
//         IReceiveUlnE2(receiverLib).verify(
//             _packetHeader,
//             _payloadHash,
//             uint64(blockConfirmation)
//         );
//     }

//     function _isV2(uint32 _eid) internal pure returns (bool) {
//         if (_eid > 30000) {
//             return true;
//         }
//         return false;
//     }

//     function _isLocal(uint32 _dstEid) internal view returns (bool) {
//         if (localEid == _dstEid || localEid == _dstEid + 30000) {
//             return true;
//         }
//         return false;
//     }

//     /// @inheritdoc ILayerZeroDVN
//     function assignJob(
//         AssignJobParam calldata _param,
//         bytes calldata /*_options*/
//     ) external payable returns (uint256 fee) {
//         if (!supportedDstChain[_param.dstEid])
//             revert UnsupportedChain(_param.dstEid);
//         if (!isSupportedMessageLib(msg.sender)) revert UnsupportedSendLib();
//         fee = chainFeeLookup[_param.dstEid];
//         emit OracleNotified(
//             _param.dstEid,
//             _param.confirmations,
//             _param.sender,
//             fee
//         );

//         if (_param.dstEid == localEid) {
//             (address receiverLib, ) = layerZeroEndpointV2.getReceiveLibrary(
//                 _param.packetHeader.receiver(),
//                 localEid
//             );
//             IReceiveUlnE2(receiverLib).verify(
//                 _param.packetHeader,
//                 _param.payloadHash,
//                 _param.confirmations
//             );
//         } else if (_param.dstEid + 30000 == localEid) {
//             address receiverLib = layerZeroEndpointV1.getReceiveLibraryAddress(
//                 _param.packetHeader.receiver()
//             );
//             IReceiveUlnE2(receiverLib).verify(
//                 _param.packetHeader,
//                 _param.payloadHash,
//                 _param.confirmations
//             );
//         }
//     }

//     /// @inheritdoc ILayerZeroDVN
//     function getFee(
//         uint32 _dstEid,
//         uint64,
//         /*_confirmations*/ address,
//         /*_sender*/ bytes calldata /*_options*/
//     ) external view returns (uint256 fee) {
//         fee = chainFeeLookup[_dstEid];
//     }

//     function hashLookup(
//         bytes calldata _encodedPayload
//     ) external view returns (bool) {
//         address receiverLib;
//         if (_isV2(_encodedPayload.srcEid())) {
//             (receiverLib, ) = layerZeroEndpointV2.getReceiveLibrary(
//                 _encodedPayload.receiver(),
//                 _encodedPayload.srcEid()
//             );
//         } else {
//             receiverLib = layerZeroEndpointV1.getReceiveLibraryAddress(
//                 _encodedPayload.receiver()
//             );
//         }

//         address receiveLibView = receiveLibToView[receiverLib];
//         if (receiveLibView == address(0x0)) revert ReceiveLibViewNotSet();
//         VerificationState state = IReceiveUlnView(receiveLibView).verifiable(
//             _encodedPayload.header(),
//             _encodedPayload.payloadHash()
//         );
//         if (
//             state == VerificationState.Verifiable ||
//             state == VerificationState.Verified
//         ) {
//             return true;
//         }

//         Verification memory verification = IReceiveUlnE2(receiverLib)
//             .hashLookup(
//                 keccak256(_encodedPayload.header()),
//                 _encodedPayload.payloadHash(),
//                 address(this)
//             );
//         return verification.submitted;
//     }

//     function feeBalance() public view returns (uint256 balance) {
//         for (uint256 i = 0; i < getLzMessageLibLength(); i++) {
//             address _messageLib = lzMessageLibs[i];
//             if (messageLibLookup[_messageLib].enabled) {
//                 balance += ISendLib(_messageLib).fees(address(this));
//             }
//         }
//     }

//     function isSupportedMessageLib(
//         address _messageLib
//     ) public view returns (bool) {
//         return messageLibLookup[_messageLib].enabled;
//     }

//     function getLzMessageLibLength() public view returns (uint256) {
//         return lzMessageLibs.length;
//     }

//     function getLzMessageLib(
//         address _msgLib
//     ) public view returns (MessageLibInfo memory) {
//         return messageLibLookup[_msgLib];
//     }

//     //----------------------------------------------------------------------------------
//     // onlyFeeManager
//     function setFees(
//         uint32[] calldata _dstEid,
//         uint256[] calldata _price
//     ) external onlyFeeManager {
//         if (_dstEid.length != _price.length) revert InvalidParameters();
//         for (uint256 i = 0; i < _dstEid.length; i++) {
//             chainFeeLookup[_dstEid[i]] = _price[i];
//             emit SetFee(_dstEid[i], _price[i]);
//         }
//     }

//     function setFee(uint32 _dstEid, uint256 _price) external onlyFeeManager {
//         chainFeeLookup[_dstEid] = _price;
//         emit SetFee(_dstEid, _price);
//     }

//     //----------------------------------------------------------------------------------
//     // onlyOwner
//     function setDstChain(uint32 _dstEid, bool enabled) external onlyOwner {
//         if (supportedDstChain[_dstEid] == enabled) revert AlreadySet();

//         supportedDstChain[_dstEid] = enabled;
//         emit DstChainStatusChanged(_dstEid, enabled);
//     }

//     function addLzMessageLib(address _messageLib) external onlyOwner {
//         messageLibLookup[_messageLib] = MessageLibInfo(
//             true,
//             MessageLibType.Send,
//             _messageLib
//         );
//         lzMessageLibs.push(_messageLib);
//     }

//     function removeLzMessageLib(address _messageLib) external onlyOwner {
//         if (!messageLibLookup[_messageLib].enabled)
//             revert MessageLibAlreadyDeleted();

//         messageLibLookup[_messageLib].enabled = false;
//         uint256 fee = ISendLib(_messageLib).fees(address(this));
//         if (fee > 0) {
//             ISendLib(_messageLib).withdrawFee(payable(owner()), fee);
//             emit WithdrawFee(_messageLib, owner(), fee);
//         }
//     }

//     function withdrawFeeAll(address payable _to) external onlyOwner {
//         uint256 _amount = 0;
//         for (uint256 i = 0; i < getLzMessageLibLength(); i++) {
//             address _messageLib = lzMessageLibs[i];
//             if (!isSupportedMessageLib(_messageLib)) {
//                 continue;
//             }
//             uint256 ulnBalance = ISendLib(_messageLib).fees(address(this));
//             if (ulnBalance > 0) {
//                 ISendLib(_messageLib).withdrawFee(_to, ulnBalance);
//                 emit WithdrawFee(_messageLib, _to, ulnBalance);
//                 _amount += ulnBalance;
//             }
//         }
//         if (_amount == 0) {
//             revert InsufficientFee();
//         }
//     }

//     function withdrawFee(
//         address _messageLib,
//         address payable _to
//     ) external onlyOwner {
//         uint256 _fee = ISendLib(_messageLib).fees(address(this));
//         if (_fee == 0) {
//             revert InsufficientFee();
//         }
//         ISendLib(_messageLib).withdrawFee(_to, _fee);

//         emit WithdrawFee(_messageLib, _to, _fee);
//     }

//     function setBlockUpdater(
//         uint32 _srcEid,
//         address _newBlockUpdater
//     ) external onlyOwner {
//         if (_newBlockUpdater == address(0)) revert ZeroAddress();
//         if (address(blockUpdaters[_srcEid]) == _newBlockUpdater)
//             revert AlreadySet();

//         emit NewBlockUpdater(
//             _srcEid,
//             address(blockUpdaters[_srcEid]),
//             _newBlockUpdater
//         );
//         blockUpdaters[_srcEid] = IBlockUpdater(_newBlockUpdater);
//     }

//     function setZKMptValidator(address _newZkMptValidator) external onlyOwner {
//         if (_newZkMptValidator == address(0)) revert ZeroAddress();
//         if (address(zkMptValidator) == _newZkMptValidator) revert AlreadySet();

//         emit NewZKMptValidator(address(zkMptValidator), _newZkMptValidator);

//         zkMptValidator = IZKMptValidator(_newZkMptValidator);
//     }

//     function setMptValidator(address _newMptValidator) external onlyOwner {
//         if (_newMptValidator == address(0)) revert ZeroAddress();
//         if (address(mptValidator) == _newMptValidator) revert AlreadySet();

//         emit NewMptValidator(address(mptValidator), _newMptValidator);

//         mptValidator = IMptValidator(_newMptValidator);
//     }

//     function setFeeManager(
//         address feeManager_,
//         bool enabled_
//     ) external onlyOwner {
//         if (feeManager_ == address(0)) revert ZeroAddress();
//         if (feeManager[feeManager_] == enabled_) revert AlreadySet();

//         feeManager[feeManager_] = enabled_;
//         emit SetFeeManager(feeManager_, enabled_);
//     }

//     function setReceiveView(
//         address receiveLib_,
//         address receiveLibView_
//     ) external onlyOwner {
//         receiveLibToView[receiveLib_] = receiveLibView_;
//     }

//     function setTrustedRemoteLookup(
//         uint32 eid,
//         address trustedRemoteAddress
//     ) external onlyOwner {
//         trustedRemoteLookup[eid] = trustedRemoteAddress;
//     }
// }
