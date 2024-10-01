// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ZkSyncChainChecker} from "foundry-devops/ZkSyncChainChecker.sol";

import {BagelToken} from "../src/BagelToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is ZkSyncChainChecker, StdInvariant, Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    bytes32 PROFF_ONE = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 PROOF_TWO = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [PROFF_ONE, PROOF_TWO];
    uint256 public CLAIM_AMOUNT = 25 * 1e18;
    uint256 public AIRDROP_SUPPLY = 100 * CLAIM_AMOUNT;

    address public user;
    uint256 public userPrivateKey;

    address public gasPayer;

    function setUp() external {
        if (!isOnZkSyncChainId()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(ROOT, token);
            token.mint(address(airdrop), AIRDROP_SUPPLY);
        }

        (user, userPrivateKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");

        targetContract(address(airdrop));
    }

    function testGasPayerCanClaimForUser() external {
        uint256 startingBalance = token.balanceOf(user);

        // sign message hash from user
        bytes32 digest = airdrop.getMessageHash(user, CLAIM_AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        vm.prank(gasPayer);
        airdrop.claim(user, CLAIM_AMOUNT, PROOF, v, r, s);

        uint256 endingBalance = token.balanceOf(user);

        assertEq(endingBalance-startingBalance, CLAIM_AMOUNT);
    }

    function testUserCannotDoubleClaim() external {
        // sign message hash from user
        bytes32 digest = airdrop.getMessageHash(user, CLAIM_AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        airdrop.claim(user, CLAIM_AMOUNT, PROOF, v, r, s);

        vm.expectRevert();
        airdrop.claim(user, CLAIM_AMOUNT, PROOF, v, r, s);

        vm.expectRevert(abi.encodeWithSelector(MerkleAirdrop.MerkleAirdrop__AlreadyClaimed.selector));
        airdrop.claim(user, CLAIM_AMOUNT, PROOF, v, r, s);

        vm.expectRevert(bytes4(MerkleAirdrop.MerkleAirdrop__AlreadyClaimed.selector));
        airdrop.claim(user, CLAIM_AMOUNT, PROOF, v, r, s);
    }

    function testFuzzGetMessageHash(address account, uint256 amount) external view {
        bytes32 digest = airdrop.getMessageHash(account, amount);
        assertEq(digest.length, 32);
    }

    function invariant_testGetMessageHash() external view {
        bytes32 digest = airdrop.getMessageHash(user, CLAIM_AMOUNT);
        assertEq(digest.length, 32);
    }
}
