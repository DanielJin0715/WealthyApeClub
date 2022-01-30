const { BigNumber } = require("@ethersproject/bignumber");
const { ethers, upgrades } = require("hardhat");

async function main_apes() {
    const ApesNFT = await ethers.getContractFactory("ApesNFT");
    const instance = await upgrades.deployProxy(ApesNFT);
    await instance.deployed();

    console.log("ApesNFT deployed to:", instance.address);
}

async function main_apes_upgrade() {
    const ApesNFTV2 = await ethers.getContractFactory('ApesNFTV2');
    await upgrades.upgradeProxy('0x2f1b6ddfc852531bfd4474dda2d4aeb2be51ce84', ApesNFTV2);
    
    console.log('ApesNFT upgraded');
}

main_apes();