const { ethers } = require('ethers');

const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '0xc4b19b885b4426974701774741F64E67977C6B17';
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC || 'https://ethereum-sepolia-rpc.publicnode.com';
const PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY || '29e0a1db9e264d9cec18bedbdfd7c78d8596018e2c3504e98aa6c693f059b416';

const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Bypass-Tunnel-Reminder'
  );

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    const blockNumber = await provider.getBlockNumber();
    const feeData = await provider.getFeeData();
    let relayerAddress = 'N/A';
    let relayerBalance = '0.0 ETH';

    if (PRIVATE_KEY && PRIVATE_KEY.length >= 64) {
      const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
      relayerAddress = wallet.address;
      const bal = await provider.getBalance(wallet.address);
      relayerBalance = `${ethers.formatEther(bal)} ETH`;
    }

    return res.status(200).json({
      success: true,
      network: 'Ethereum Sepolia Testnet',
      chainId: 11155111,
      latestBlock: blockNumber,
      gasPriceGwei: feeData.gasPrice ? ethers.formatUnits(feeData.gasPrice, 'gwei') : 'N/A',
      contractAddress: CONTRACT_ADDRESS,
      etherscanContractUrl: `https://sepolia.etherscan.io/address/${CONTRACT_ADDRESS}`,
      relayerAddress,
      relayerBalance
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
};
