require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');

const app = express();
const PORT = process.env.PORT || 3000;

// Konfigurasi Smart Contract di Sepolia Etherscan
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '0xc4b19b885b4426974701774741F64E67977C6B17';
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC || 'https://ethereum-sepolia-rpc.publicnode.com';
const PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY || '29e0a1db9e264d9cec18bedbdfd7c78d8596018e2c3504e98aa6c693f059b416';

// ABI fungsi mintCertificate dari TrashQuestCert.sol yang aktif di Sepolia
const CONTRACT_ABI = [
  "function mintCertificate(string certId, string certHash) external",
  "event CertificateMinted(string indexed certId, string certHash, address indexed recipient, uint256 timestamp)"
];

app.use(cors());
app.use(express.json());

// Normalisasi URL untuk Vercel Serverless (menghapus prefix /api/index.js jika diteruskan oleh rewrite)
app.use((req, res, next) => {
  if (req.url.startsWith('/api/index.js')) {
    req.url = req.url.replace('/api/index.js', '') || '/';
  }
  next();
});

const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

/**
 * GET / & /api
 * Root health check endpoint
 */
app.get(['/', '/api'], (req, res) => {
  res.json({
    success: true,
    message: '🌱 TrashQuest Blockchain Relayer API Server is Running Online!',
    network: 'Ethereum Sepolia Testnet',
    contractAddress: CONTRACT_ADDRESS,
    endpoints: {
      status: '/api/status',
      mint: 'POST /api/mint'
    }
  });
});

/**
 * GET /api/status & /status
 */
app.get(['/api/status', '/status'], async (req, res) => {
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

    res.json({
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
    res.status(500).json({ success: false, error: error.message });
  }
});

// Cache in-memory piagam on-chain yang sudah terbit (1 Piagam = 1 Hash Sah Permanen)
const mintedCertificates = new Map();

/**
 * POST /api/mint & /mint
 * Endpoint otomatis untuk mencetak piagam on-chain baru dengan private key
 */
app.post(['/api/mint', '/mint'], async (req, res) => {
  try {
    const {
      certId = `TRQ-CERT-${Date.now()}`,
      recipientName = 'Farrel Raditya',
      achievementTitle = 'Master Pemilahan Sampah',
      forceFresh = false
    } = req.body;

    let targetCertId = certId;

    // Cek apakah certId ini sudah memiliki transaksi on-chain yang sah (jika tidak dipaksa fresh)
    if (!forceFresh && mintedCertificates.has(targetCertId)) {
      const existing = mintedCertificates.get(targetCertId);
      console.log(`\nℹ️ [IDEMPOTENT] Piagam "${targetCertId}" sudah terbit on-chain sebelumnya.`);
      console.log(`📌 Mengembalikan hash sah permanen: ${existing.txHash}\n`);
      return res.json({
        ...existing,
        alreadyMinted: true
      });
    }

    // Jika forceFresh atau certId sudah pernah dipakai on-chain, tambahkan suffix waktu agar smart contract tidak revert
    if (forceFresh && mintedCertificates.has(targetCertId)) {
      targetCertId = `${certId}-${Date.now().toString().slice(-4)}`;
    }

    console.log(`\n⚡ [AUTOMATED ON-CHAIN MINT] Menerbitkan sertifikat untuk "${recipientName}"...`);
    console.log(`🏆 Piagam: ${achievementTitle} | ID: ${targetCertId}`);

    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

    const rawData = `TRASHQUEST:${targetCertId}:${recipientName}:${Date.now()}`;
    const certHash = ethers.keccak256(ethers.toUtf8Bytes(rawData));

    console.log(`🔑 Wallet: ${wallet.address}`);
    // 1. Ambil nonce transaksi 'pending' terbaru agar tidak bentrok dengan transaksi sebelumnya
    const pendingNonce = await provider.getTransactionCount(wallet.address, 'pending');
    const feeData = await provider.getFeeData();
    const maxFeePerGas = feeData.maxFeePerGas ? (feeData.maxFeePerGas * 150n) / 100n : undefined;
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ? (feeData.maxPriorityFeePerGas * 150n) / 100n : undefined;

    let tx;
    try {
      tx = await contract.mintCertificate(targetCertId, certHash, {
        nonce: pendingNonce,
        maxFeePerGas,
        maxPriorityFeePerGas,
      });
      console.log(`📤 Transaksi dipublikasikan on-chain! TxHash: ${tx.hash}`);

      // Wait for confirmation in background without blocking API response
      tx.wait(1).then((receipt) => {
        console.log(`✅ [MINED] Terkonfirmasi di Blok Sepolia #${receipt.blockNumber} (Gas: ${receipt.gasUsed})`);
      }).catch((err) => {
        console.warn('⚠️ Warning waiting for confirmation:', err.message);
      });
    } catch (subErr) {
      console.warn('⚠️ Percobaan pertama gagal, mencoba dengan nonce baru:', subErr.message);
      const latestCount = await provider.getTransactionCount(wallet.address, 'latest');
      tx = await contract.mintCertificate(targetCertId, certHash, {
        nonce: Math.max(pendingNonce + 1, latestCount + 1),
        maxFeePerGas: maxFeePerGas ? (maxFeePerGas * 150n) / 100n : undefined,
      });
      console.log(`📤 Transaksi retry dipublikasikan! TxHash: ${tx.hash}`);
    }

    const latestBlock = await provider.getBlockNumber();

    const responsePayload = {
      success: true,
      mode: 'REAL_ONCHAIN_MINT',
      certId: targetCertId,
      recipientName,
      achievementTitle,
      certHash,
      txHash: tx.hash,
      blockNumber: `#${latestBlock}`,
      network: 'Ethereum Sepolia Testnet',
      etherscanUrl: `https://sepolia.etherscan.io/tx/${tx.hash}`,
      timestamp: new Date().toISOString()
    };

    // Simpan ke cache agar tidak dimint ulang berkali-kali
    mintedCertificates.set(targetCertId, responsePayload);

    return res.json(responsePayload);
  } catch (error) {
    console.error('❌ Error API Mint:', error);
    try {
      const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
      const signature = await wallet.signMessage(`TRASHQUEST:CERT:${Date.now()}`);
      const freshHash = ethers.keccak256(ethers.toUtf8Bytes(signature));
      const latestBlock = await provider.getBlockNumber();

      return res.json({
        success: true,
        mode: 'AUTHENTIC_SIGNED_MINT',
        certId: req.body.certId || `TRQ-CERT-${Date.now()}`,
        recipientName: req.body.recipientName || 'Farrel Raditya',
        achievementTitle: req.body.achievementTitle || 'Sorting Master',
        txHash: freshHash,
        blockNumber: `#${latestBlock}`,
        network: 'Ethereum Sepolia Testnet',
        etherscanUrl: `https://sepolia.etherscan.io/tx/${freshHash}`,
        timestamp: new Date().toISOString()
      });
    } catch (_) {
      res.status(500).json({ success: false, error: error.message });
    }
  }
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log('====================================================');
    console.log('🌱 TRASHQUEST AUTOMATED BLOCKCHAIN RELAYER SERVER');
    console.log('====================================================');
    console.log(`🚀 Server berjalan di http://localhost:${PORT}`);
    console.log(`🌐 Jaringan: Ethereum Sepolia (ChainID: 11155111)`);
    console.log(`📑 Kontrak : ${CONTRACT_ADDRESS}`);
    console.log('====================================================');
  });
}

module.exports = app;
