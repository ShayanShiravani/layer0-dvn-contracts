// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Particle is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721BurnableUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId;

    uint256 public totalValue;
    mapping(uint256 => uint256) public valueOfToken;

    event Merge(uint256 formTokenId, uint256 toTokenId);
    event Split(uint256 tokenId, uint256 value);

    error NotOwned();
    error InvalidValue();
    error SameTokenId();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address msig) public initializer {
        __ERC721_init("Particle", "PRT");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC721Pausable_init();
        __AccessControlEnumerable_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msig);
        _grantRole(PAUSER_ROLE, msig);
        _grantRole(UNPAUSER_ROLE, msig);
        _grantRole(MINTER_ROLE, msig);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    function safeMint(
        address to,
        uint256 value,
        string memory uri
    ) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        totalValue += value;
        valueOfToken[tokenId] = value;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721PausableUpgradeable
        )
        returns (address)
    {
        // Update valueOfToken and totalValue on transfer to zero
        if (to == address(0)) {
            totalValue -= valueOfToken[tokenId];
            valueOfToken[tokenId] = 0;
        }

        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlEnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function merge(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external whenNotPaused {
        if (fromTokenId == toTokenId) revert SameTokenId();

        if (
            _ownerOf(fromTokenId) != msg.sender ||
            _ownerOf(toTokenId) != msg.sender
        ) {
            revert NotOwned();
        }

        totalValue += valueOfToken[fromTokenId];
        valueOfToken[toTokenId] += valueOfToken[fromTokenId];
        _burn(fromTokenId);

        emit Merge(fromTokenId, toTokenId);
    }

    function split(uint256 tokenId, uint256 value) external whenNotPaused {
        if (_ownerOf(tokenId) != msg.sender) {
            revert NotOwned();
        }
        if (value >= valueOfToken[tokenId]) {
            revert InvalidValue();
        }

        valueOfToken[tokenId] -= value;

        uint256 newTokenId = _nextTokenId++;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI(tokenId));
        valueOfToken[newTokenId] = value;

        emit Split(tokenId, value);
    }

    function burnFrom(
        address from,
        uint256 tokenId
    ) external returns (bytes memory params) {
        params = encodeParams(from, tokenId);
        _burn(tokenId);
        totalValue -= valueOfToken[tokenId];
        valueOfToken[tokenId] = 0;
    }

    function mintTo(bytes calldata params) external onlyRole(MINTER_ROLE) {
        (address recipient, uint256 tokenId, uint256 value) = decodeParams(
            params
        );
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI(tokenId));
        totalValue += value;
        valueOfToken[tokenId] = value;
    }

    function encodeParams(
        address from,
        uint256 id
    ) public view virtual returns (bytes memory) {
        return abi.encode(from, id, valueOfToken[id]); // Encodes payload.
    }

    function decodeParams(
        bytes calldata data
    ) public pure returns (address recipient, uint256 tokenId, uint256 value) {
        (recipient, tokenId, value) = abi.decode(
            data,
            (address, uint256, uint256)
        );
    }
}
