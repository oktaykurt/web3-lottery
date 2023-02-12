const { network, ethers } = require("hardhat");
const {
  networkConfig,
  VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("/helper-hardhat-config");
const { verify } = require("/utils/verify");

const FUND_AMOUNT = ethers.utils.parseEther("1"); // 1 ETH

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  const arguments = [
    networkConfig[chainId]["vrfCoordiantorV2"],
    networkConfig[chainId]["subscriptionId"],
    networkConfig[chainId]["gasLane"],
    networkConfig[chainId]["keepersUpdateInterval"],
    networkConfig[chainId]["raffleEntranceFee"],
    networkConfig[chainId]["callbackGasLimit"],
  ];

  const raffle = await deploy("Raffle", {
    from: deployer,
    args: arguments,
    log: true,
    waitConfirmation: VERIFICATION_BLOCK_CONFIRMATIONS,
  });

  // Verify the contract after deployment
  if (proccess.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(raffle.address, arguments);
  }

  log("Enter lottery with command:");
  const networkName = network.name;
  log(`yarn hardhat run scripts/enterRaffle.js --network ${networkName}`);
  log("----------------------------------------------------");
};

module.exports.tags = ["all", "raffle"];
