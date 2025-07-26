const SimpleDEX = await ethers.getContractFactory("SimpleDEX");
const dex = await SimpleDEX.deploy(tokenAAddress, tokenBAddress); // <- esses precisam ser reais
await dex.deployed();
