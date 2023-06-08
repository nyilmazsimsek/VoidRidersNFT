// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoidRidersNFT is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    string public base_uri = "";
    string public uriSuffix = "";
    string public hiddenMetadataUri;

    uint256 public mintPrice = 0.00001 ether;
    uint256 public maxSupply = 2083;
    uint256 public reservedForTeam = 22;
    uint256 public mintedForTeam;
    uint256 public nftPerAddressLimit = 3;

    bool public paused = true;
    bool public revealed = false;
    bool public onlyWhitelisted = true;

    mapping(address => bool) public whitelistedAddresses;
    mapping(address => uint256) public addressMintedBalance;

    constructor() ERC721("Void Riders NFT", "VR") {
        setHiddenMetadataUri("");
        paused = false;
        onlyWhitelisted = false;
    }

    //-------- MINT FUNCTIONS-----------------

    //Allows users to mint new tokens. Users can mint multiple tokens at once by passing the _mintAmount parameter.
    //The function checks if the contract is paused, if the amount of ether sent is sufficient for
    //the required mint price, and if the maximum number of tokens allowed to be minted in a single transaction is not exceeded.
    function mint(uint256 _mintAmount) public payable {
        require(!paused, "The contract is paused!");
        if (onlyWhitelisted) {
            require(
                whitelistedAddresses[msg.sender],
                "Wallet is not in WhiteList"
            );
        }
        require(
            _mintAmount > 0 && _mintAmount <= nftPerAddressLimit,
            "Invalid mint amount!"
        );
        require(
            supply.current() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        require(
            addressMintedBalance[msg.sender] < nftPerAddressLimit,
            "Max supply exceeded for wallet!"
        );
        require(msg.value >= mintPrice * _mintAmount, "Insufficient funds!");


        _mintLoop(msg.sender, _mintAmount);
    }

    //allows the contract owner to mint new tokens on behalf of another address.
    function mintForAddress(
        uint256 _mintAmount,
        address _receiver
    ) public onlyOwner {
        require(
            supply.current() + _mintAmount <= maxSupply && mintedForTeam + _mintAmount <= reservedForTeam,
            "Max supply exceeded!"
        );
        _mintLoop(_receiver, _mintAmount);
    }

    // to mint the requested number of tokens
    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            addressMintedBalance[_receiver]++;
            supply.increment();
            _safeMint(_receiver, supply.current());
        }
    }

    //-------- GET FUNCTIONS-----------------

    function _baseURI() internal view virtual override returns (string memory) {
        return base_uri;
    }

    // returns the total number of tokens that have been minted so far.
    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    // returns the state of given address for whitelist
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelistedAddresses[_address];
    }

    //A function that returns an array of token IDs owned by a specific _owner.
    //It iterates through all token IDs and returns an array of IDs that belong to the specified _owner.
    function walletOfOwner(
        address _owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    //returns the metadata URI of a specific token ID. If revealed is false, the function returns the hiddenMetadataUri.
    //If revealed is true, the function constructs and returns the URI of the token using the uriPrefix, _tokenId, and uriSuffix variables.
    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    //-------- ALLOWED ADDRESSES-----------------

    function addAllowedAddress(address[] calldata _address) external onlyOwner {
        for (uint256 i = 0; i < _address.length; i++) {
            require(_address[i] != address(0), "Address cannot be empty.");
            if (whitelistedAddresses[_address[i]]) {
                require(false, "Address already exists."); //Force throw exception
            }
            whitelistedAddresses[_address[i]] = true;
        }
    }

    function removeAllowedAddress(
        address[] calldata _address
    ) external onlyOwner {
        for (uint256 i = 0; i < _address.length; i++) {
            require(_address[i] != address(0), "Address cannot be empty.");
            require(
                whitelistedAddresses[_address[i]],
                "Address already removed."
            ); //Force throw exception
            whitelistedAddresses[_address[i]] = false;
        }
    }

    //-------- SET FUNCTIONS-----------------

    // allows the contract owner to set the revealed variable to true or false.
    //If revealed is set to false, the tokenURI() function will return the hiddenMetadataUri for all token IDs.
    function flipRevealed() public onlyOwner {
        revealed = !revealed;
    }

    //allows the contract owner to set the mintPrice variable to a new value.
    function changePrice(uint256 _newPrice) public onlyOwner {
        mintPrice = _newPrice;
    }

    //allows the contract owner to set the maximum number of tokens that can be minted in a single transaction.
    function setMaxMintAmountPerWallet(
        uint256 _maxMintAmountPerTx
    ) public onlyOwner {
        nftPerAddressLimit = _maxMintAmountPerTx;
    }

    //allows the contract owner to set the hiddenMetadataUri variable to a new value.
    function setHiddenMetadataUri(
        string memory _hiddenMetadataUri
    ) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    //allows the contract owner to set the uriPrefix variable to a new value.
    function setBaseURI(string memory newUri) public onlyOwner {
        base_uri = newUri;
    }

    //allows the contract owner to set the uriSuffix variable to a new value.
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    //allows the contract owner to pause or unpause the contract.
    function flipPaused() public onlyOwner {
        paused = !paused;
    }

    //allows the contract owner to pause or unpause the whitelisted sale.
    function flipOnlyWhitelisted() public onlyOwner {
        onlyWhitelisted = !onlyWhitelisted;
    }

    //-------- WALLET FUNCTIONS-----------------

    //used to withdraw the balance of the contract to the owner's address.
    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}
