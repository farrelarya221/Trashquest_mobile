const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '0xc4b19b885b4426974701774741F64E67977C6B17';

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  return res.status(200).json({
    success: true,
    message: '🌱 TrashQuest Blockchain Relayer API Server is Running Online on Vercel!',
    network: 'Ethereum Sepolia Testnet',
    contractAddress: CONTRACT_ADDRESS,
    endpoints: {
      status: '/api/status',
      mint: 'POST /api/mint'
    }
  });
};
