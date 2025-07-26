const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenA", function () {
  let TokenA, token, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    TokenA = await ethers.getContractFactory("TokenA");
    token = await TokenA.deploy(1000); // initial totalSupply
    await token.deployed();
  });

  it("Should have the correct name and symbol", async function () {
    expect(await token.name()).to.equal("Token A");
    expect(await token.symbol()).to.equal("TKA");
  });

  it("Should have the correct totalSupply after deployment", async function () {
    expect(await token.totalSupply()).to.equal(1000);
    expect(await token.balanceOf(owner.address)).to.equal(1000);
  });

  it("Should transfer tokens correctly", async function () {
    await token.transfer(addr1.address, 200);
    expect(await token.balanceOf(addr1.address)).to.equal(200);
    expect(await token.balanceOf(owner.address)).to.equal(800);
  });

  it("Should mint tokens correctly", async function () {
    await token.mint(addr1.address, 500);
    expect(await token.balanceOf(addr1.address)).to.equal(500);
    expect(await token.totalSupply()).to.equal(1500);
  });

  it("Should burn tokens correctly", async function () {
    await token.burn(300);
    expect(await token.balanceOf(owner.address)).to.equal(700);
    expect(await token.totalSupply()).to.equal(700);
  });

  it("Should approve and allow transferFrom", async function () {
    await token.approve(addr1.address, 400);
    const tokenFromAddr1 = token.connect(addr1);
    await tokenFromAddr1.transferFrom(owner.address, addr2.address, 400);

    expect(await token.balanceOf(addr2.address)).to.equal(400);
    expect(await token.allowance(owner.address, addr1.address)).to.equal(0);
  });
});
