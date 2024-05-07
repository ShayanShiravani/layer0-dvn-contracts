// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMRC721 is IERC721 {
    function mintTo(bytes calldata params) external;

    function burnFrom(
        address from,
        uint256 tokenId
    ) external returns (bytes memory params);

    function encodeParams(
        address from,
        uint256 id
    ) external returns (bytes memory);
}
