// SPDX-License-Identifier: MIT
/*
    Apes / 2022
*/
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

interface IUtilityToken {
    function burn(address _from, uint256 _amount) external;

    function decimals() external pure returns (uint8);
}

interface IStakingPool {
    function startStaking(address _user, uint256 _tokenId) external;

    function stopStaking(address _user, uint256 _tokenId) external;
}

contract ApesNFT is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;

    enum ApesType {
        M1,
        M2,
        M3
    }

    struct ApesInfo {
        ApesType aType;
        bool bStaked;
        // uint256 lastBreedTime;
    }

    event ApesMinted(
        address indexed user,
        uint256 indexed tokenId,
        uint256 indexed aType
    );

    uint256 public constant MINT_PRICE = 50000000000000000; // 0.05 ETH
    uint256 public constant BREED_PRICE = 100000000000000000; // 0.1 ETH
    uint256 public constant EVOLVE_PRICE = 1000000000000000000; // 1 ETH

    uint256[] private START_ID_BY_TYPE;
    uint256[] private MAX_SUPPLY_BY_TYPE;
    uint256[] public totalSupplyByType;

    uint256 public constant MAX_SUPPLY_FOR_FREE = 270; // 250 + 20;
    uint256 public constant MAX_APES_PURCHASE = 20;
    uint256 public constant MAX_FREE_FOR_USER = 10;
    mapping(address => uint256) private claimInFree;

    address public royaltyReceiver;
    uint256 public royaltyPercent;
    uint256 public DENOMINATOR;

    bool public bMintAvailable;
    bool public bStakingAvailable;
    bool public bBreedingAvailable;

    mapping(uint256 => ApesInfo) public apes;

    string public _baseTokenURI;

    IUtilityToken private _utilityToken;
    IStakingPool private _pool;

    function initialize() public initializer {
        __ERC721_init("Wealthy ape club", "WAC");
        __Ownable_init();

        START_ID_BY_TYPE = [0, 7000, 6800];
        MAX_SUPPLY_BY_TYPE = [6666, 6666, 100];
        totalSupplyByType = [0, 0, 0];

        royaltyReceiver = 0xd8378Be0D049EcE73da320252b6399E9584dE949;
        royaltyPercent = 10;
        DENOMINATOR = 100;

        bMintAvailable = true;
        bStakingAvailable = false;
        bBreedingAvailable = true;

        _baseTokenURI = "https://apes-backend.herokuapp.com/temp/metadata/token/";

        // 20 Apes will be held in the Vault for Promotional purposes
        for (uint256 i = 0; i < 20; i++) mintOne(ApesType.M1);
    }

    function setRoyaltyConfig(
        address _royaltyReceiver,
        uint256 _royaltyPercent,
        uint256 _DENOMINATOR
    ) external onlyOwner {
        royaltyReceiver = _royaltyReceiver;
        royaltyPercent = _royaltyPercent;
        DENOMINATOR = _DENOMINATOR;
    }

    /**
     * @dev return the Base URI of the token
     */

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev set the _baseTokenURI
     * @param _newURI of the _baseTokenURI
     */

    function setBaseURI(string calldata _newURI) external onlyOwner {
        _baseTokenURI = _newURI;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Balance is zero");
        payable(msg.sender).transfer(balance);
    }

    function getApesType(uint256 _tokenId) public view returns (uint256) {
        return uint256(apes[_tokenId].aType);
    }

    function setMintAvailable() external onlyOwner {
        bMintAvailable = true;
    }

    /**
     * @dev free for first 250, 0.05 ETH for afterwards
     */
    function mintNFT(uint256 numberOfTokens) external payable {
        require(bMintAvailable, "Minting is not available yet");
        require(
            numberOfTokens > 0 && numberOfTokens <= MAX_APES_PURCHASE,
            "Can only mint 20 tokens at a time"
        );
        require(
            totalSupplyByType[uint256(ApesType.M1)] <
                MAX_SUPPLY_BY_TYPE[uint256(ApesType.M1)],
            "Exceed max supply of Apes NFT"
        );
        if (
            numberOfTokens >
            MAX_SUPPLY_BY_TYPE[uint256(ApesType.M1)] -
                totalSupplyByType[uint256(ApesType.M1)]
        )
            numberOfTokens =
                MAX_SUPPLY_BY_TYPE[uint256(ApesType.M1)] -
                totalSupplyByType[uint256(ApesType.M1)];
        uint256 freeMintableCnt = 0;
        uint256 personalFreeMintable = MAX_FREE_FOR_USER -
            claimInFree[msg.sender];
        if (
            personalFreeMintable > 0 &&
            totalSupplyByType[uint256(ApesType.M1)] < MAX_SUPPLY_FOR_FREE
        ) {
            freeMintableCnt =
                MAX_SUPPLY_FOR_FREE -
                totalSupplyByType[uint256(ApesType.M1)];
            if (freeMintableCnt > personalFreeMintable) {
                freeMintableCnt = personalFreeMintable;
            }
        }
        uint256 payfulAmount = numberOfTokens;
        if (freeMintableCnt > numberOfTokens) {
            freeMintableCnt = numberOfTokens;
            payfulAmount = 0;
        } else {
            payfulAmount = numberOfTokens - freeMintableCnt;
        }
        uint256 royaltyFee = MINT_PRICE
            .mul(numberOfTokens)
            .mul(royaltyPercent)
            .div(DENOMINATOR);
        require(
            msg.value >= MINT_PRICE * payfulAmount + royaltyFee,
            "Invalid Amount"
        );
        uint256 mintIndex = totalSupplyByType[uint256(ApesType.M1)];
        totalSupplyByType[uint256(ApesType.M1)] += numberOfTokens;
        claimInFree[msg.sender] += freeMintableCnt;
        uint256 restAmount = msg.value - MINT_PRICE * payfulAmount - royaltyFee;
        payable(msg.sender).transfer(restAmount);
        payable(royaltyReceiver).transfer(royaltyFee);
        payable(owner()).transfer(address(this).balance);
        for (uint256 i = 1; i <= numberOfTokens; i++) {
            _safeMint(msg.sender, mintIndex + i);
            apes[mintIndex + i].aType = ApesType.M1;
        }
    }

    function mintOne(ApesType _type) private {
        require(msg.sender == tx.origin);
        require(
            totalSupplyByType[uint256(_type)] <
                MAX_SUPPLY_BY_TYPE[uint256(_type)],
            "All tokens are minted"
        );

        uint256 tokenId = ++totalSupplyByType[uint256(_type)];
        tokenId += START_ID_BY_TYPE[uint256(_type)];
        _safeMint(msg.sender, tokenId);
        apes[tokenId].aType = _type;

        emit ApesMinted(msg.sender, tokenId, uint256(_type));
    }

    function setUtilitytoken(address _addr) external onlyOwner {
        _utilityToken = IUtilityToken(_addr);
    }

    function setStakingPool(address _addr) external onlyOwner {
        _pool = IStakingPool(_addr);
    }

    /*******************************************************************************
     ***                            Staking Logic                                 ***
     ******************************************************************************** */
    function setStakingAvailable() external onlyOwner {
        bStakingAvailable = true;
    }

    function startStaking(uint256 _tokenId) external {
        require(bStakingAvailable, "Staking Mechanism is not started yet");
        require(ownerOf(_tokenId) == msg.sender, "Staking: owner not matched");
        require(
            !apes[_tokenId].bStaked,
            "This Token is already staked. Please try another token."
        );

        _pool.startStaking(msg.sender, _tokenId);
        _safeTransfer(msg.sender, address(_pool), _tokenId, "");
        apes[_tokenId].bStaked = true;
    }

    function stopStaking(uint256 _tokenId) external {
        require(
            apes[_tokenId].bStaked,
            "This token hasn't ever been staked yet."
        );
        _pool.stopStaking(msg.sender, _tokenId);
        _safeTransfer(address(_pool), msg.sender, _tokenId, "");
        apes[_tokenId].bStaked = false;
    }

    /*******************************************************************************
     ***                            Adopting Logic                               ***
     ********************************************************************************/
    function setBreedingAvailable() external onlyOwner {
        bBreedingAvailable = true;
    }

    function adopt(uint256 _parent) external payable {
        require(bBreedingAvailable, "Adopting M2 is not ready yet");
        require(
            apes[_parent].aType != ApesType.M2,
            "Try adopting with M1 or M3"
        );
        require(msg.value >= BREED_PRICE, "No enough pay to breed");
        require(
            ownerOf(_parent) == msg.sender,
            "Adopting: You're not owner of this token"
        );
        require(
            !apes[_parent].bStaked,
            "This Token is already staked. Please try another token."
        );
        mintOne(ApesType.M2);
    }

    /*******************************************************************************
     ***                            Evolution Logic                              ***
     ********************************************************************************/
    function evolve(uint256 _tokenId) external payable {
        require(bBreedingAvailable, "Evolving Apes is not ready yet");
        require(
            ownerOf(_tokenId) == msg.sender,
            "Evolve: You're not owner of this token"
        );
        require(apes[_tokenId].aType == ApesType.M1, "M1 can only evolve M3");
        require(msg.value >= EVOLVE_PRICE, "No enough pay to evolve");
        require(
            !apes[_tokenId].bStaked,
            "This Token is already staked. Please try another token."
        );
        mintOne(ApesType.M3);
    }
}
