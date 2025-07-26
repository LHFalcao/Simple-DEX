const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleDEX", function () {
  let TokenA, TokenB, tokenA, tokenB, DEX, dex;
  let owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    TokenA = await ethers.getContractFactory("TokenA");
    TokenB = await ethers.getContractFactory("TokenB");
    DEX = await ethers.getContractFactory("SimpleDEX_V2");

    tokenA = await TokenA.deploy(1000);
    tokenB = await TokenB.deploy(1000);
    await tokenA.deployed();
    await tokenB.deployed();

    dex = await DEX.deploy(tokenA.address, tokenB.address);
    await dex.deployed();

    await tokenA.approve(dex.address, 500);
    await tokenB.approve(dex.address, 500);
    await dex.addLiquidity(500, 500);
  });

  it("Should store token addresses correctly", async function () {
    expect(await dex.tokenA()).to.equal(tokenA.address);
    expect(await dex.tokenB()).to.equal(tokenB.address);
  });

  it("Should add liquidity correctly", async function () {
    expect(await tokenA.balanceOf(dex.address)).to.equal(500);
    expect(await tokenB.balanceOf(dex.address)).to.equal(500);
  });

  it("Should emit LiquidityAdded event", async function () {
    await tokenA.mint(owner.address, 100);
    await tokenB.mint(owner.address, 100);
    await tokenA.approve(dex.address, 100);
    await tokenB.approve(dex.address, 100);

    await expect(dex.addLiquidity(100, 100))
      .to.emit(dex, "LiquidityAdded")
      .withArgs(owner.address, 100, 100);
  });

  it("Should remove liquidity correctly", async function () {
    await expect(dex.removeLiquidity(100, 100)).to.changeTokenBalances(
      tokenA,
      [dex, owner],
      [-100, 100]
    );
  });

  it("Should revert if trying to remove more liquidity than reserves", 
  async function () {
  await expect(
    dex.removeLiquidity(9999, 9999)
  ).to.be.revertedWithCustomError(dex, "InsufficientReserves");
});

  it("Should emit LiquidityRemoved event", async function () {
    await expect(dex.removeLiquidity(100, 100))
      .to.emit(dex, "LiquidityRemoved")
      .withArgs(owner.address, 100, 100);
  });

  it("Should swap A for B correctly", async function () {
    await tokenA.transfer(addr1.address, 100);
    await tokenA.connect(addr1).approve(dex.address, 100);
    await expect(dex.connect(addr1).swapAforB(100))
      .to.emit(dex, "TokensSwapped");
  });

  it("Should swap B for A correctly", async function () {
    await tokenB.transfer(addr1.address, 100);
    await tokenB.connect(addr1).approve(dex.address, 100);
    await expect(dex.connect(addr1).swapBforA(100))
      .to.emit(dex, "TokensSwapped");
  });

  it("Should revert if trying to add zero liquidity", async function () {
    await expect(dex.addLiquidity(0, 100)).to.be.revertedWithCustomError(
      dex,
      "InvalidLiquidityAmounts"
    );
  });

  it("Should get correct price of tokenA in B", async function () {
    const price = await dex.getPrice(tokenA.address);
    expect(price).to.be.instanceOf(ethers.BigNumber);
    expect(price.gt(0)).to.be.true;
  });

  it("Should get correct price of tokenB in A", async function () {
    const price = await dex.getPrice(tokenB.address);
    expect(price).to.be.instanceOf(ethers.BigNumber);
    expect(price.gt(0)).to.be.true;
  });
});

describe("Edge cases - getPrice", function () {

  it("Should revert if invalid token is passed to getPrice", async function () {
  const TokenA = await ethers.getContractFactory("TokenA");
  const TokenB = await ethers.getContractFactory("TokenB");
  const FakeToken = await ethers.getContractFactory("TokenA");

  const tokenA = await TokenA.deploy(1000);
  const tokenB = await TokenB.deploy(1000);
  const fake = await FakeToken.deploy(1);

  await tokenA.deployed();
  await tokenB.deployed();
  await fake.deployed();

  const DEX = await ethers.getContractFactory("SimpleDEX_V2");
  const dexInvalid = await DEX.deploy(tokenA.address, tokenB.address);
  await dexInvalid.deployed();

  await tokenA.approve(dexInvalid.address, 100);
  await tokenB.approve(dexInvalid.address, 100);
  await dexInvalid.addLiquidity(100, 100); // agora tem liquidez

  await expect(
    dexInvalid.getPrice(fake.address)
  ).to.be.revertedWithCustomError(dexInvalid, "InvalidToken");
});
});
