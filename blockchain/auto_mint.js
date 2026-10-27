/**
 * TrashQuest Automated Certificate Minting Script
 * -----------------------------------------------
 * Skrip ini mengotomatiskan pencetakan piagam langsung ke jaringan Ethereum Sepolia
 * tanpa perlu membuka dan mengetik manual di Remix IDE!
 *
 * Menggunakan Wallet Deployer: 0x611f5a3A70Acea633ECA8DD0ab7C7d5F5aA9a5bE
 * Kontrak Sepolia: 0xc4b19b885b4426974701774741F64E67977C6B17
 */

require('dotenv').config();
const { ethers } = require("ethers");

// Konfigurasi Smart Contract TrashQuest di Sepolia Etherscan
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || "0xc4b19b885b4426974701774741F64E67977C6B17";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com";
const PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY || "29e0a1db9e264d9cec18bedbdfd7c78d8596018e2c3504e98aa6c693f059b416";

// ABI fungsi mintCertificate dari TrashQuestCert.sol yang aktif di Sepolia
const CONTRACT_ABI = [
  "function mintCertificate(string certId, string certHash) external",
  "event CertificateMinted(string indexed certId, string certHash, address indexed recipient, uint256 timestamp)"
];

async function mintAuto(certId, recipientName, achievementTitle) {
  console.log("=================================================");
  console.log("🚀 MEMULAI PROSES MINTING OTOMATIS TRASHQUEST");
  console.log("=================================================");
  console.log(`📌 ID Sertifikat   : ${certId}`);
  console.log(`👤 Nama Penerima   : ${recipientName}`);
  console.log(`🏆 Judul Piagam    : ${achievementTitle}`);
  console.log(`🌐 Jaringan        : Ethereum Sepolia (ChainID: 11155111)`);
  console.log(`📑 Smart Contract  : ${CONTRACT_ADDRESS}`);
  console.log("-------------------------------------------------");

  try {
    const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log(`🔑 Wallet Admin    : ${wallet.address}`);

    const balance = await provider.getBalance(wallet.address);
    console.log(`💰 Saldo Sepolia   : ${ethers.formatEther(balance)} ETH`);

    // Generate hash sertifikat unik berbasis kriptografi keccak256
    const rawData = `TRASHQUEST:${certId}:${recipientName}:${Date.now()}`;
    const certHash = ethers.keccak256(ethers.toUtf8Bytes(rawData));
    console.log(`🔒 Hash Sertifikat : ${certHash}`);

    // Inisialisasi Kontrak
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

    // Panggil fungsi mintCertificate otomatis on-chain
    console.log("\n⏳ Mengirim transaksi langsung ke mempool Sepolia...");
    const tx = await contract.mintCertificate(certId, certHash);
    console.log(`📝 Transaksi Terkirim! TxHash: ${tx.hash}`);

    console.log("⏳ Menunggu konfirmasi blok oleh validator (mining)...");
    const receipt = await tx.wait(1);

    console.log("\n=================================================");
    console.log("✅ PIAGAM BARU BERHASIL DICATAT PERMANEN ON-CHAIN!");
    console.log("=================================================");
    console.log(`📦 Blok Nomor      : #${receipt.blockNumber}`);
    console.log(`⛽ Gas Digunakan    : ${receipt.gasUsed.toString()} Gas`);
    console.log(`📝 TxHash Baru     : ${tx.hash}`);
    console.log(`🔗 Cek di Etherscan : https://sepolia.etherscan.io/tx/${tx.hash}`);
    console.log("=================================================");

    return {
      success: true,
      mode: 'REAL_ONCHAIN_MINT',
      txHash: tx.hash,
      certHash: certHash,
      blockNumber: `#${receipt.blockNumber}`,
      gasUsed: receipt.gasUsed.toString(),
      etherscanUrl: `https://sepolia.etherscan.io/tx/${tx.hash}`
    };
  } catch (err) {
    console.error("❌ Gagal melakukan minting otomatis on-chain:", err.message);
    throw err;
  }
}

// Menjalankan dari command line arguments
if (require.main === module) {
  const args = process.argv.slice(2);
  const certId = args[0] || `TRQ-CERT-SORTING_MASTER-${Math.floor(10000 + Math.random() * 90000)}`;
  const name = args[1] || "Farrel Raditya";
  const title = args[2] || "Sorting Master";

  mintAuto(certId, name, title);
}

module.exports = { mintAuto };
