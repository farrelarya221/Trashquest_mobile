// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TrashQuestCert
 * @dev Soulbound Smart Contract untuk Sertifikat & Piagam Daur Ulang TrashQuest di Ethereum Sepolia.
 * Kontrak ini sudah terverifikasi di Sepolia Etherscan:
 * Address: 0xc4b19b885b4426974701774741F64E67977C6B17
 */
contract TrashQuestCert {
    string public name = "TrashQuest Eco Certificate";
    string public symbol = "TQ-CERT";
    address public owner;

    struct Certificate {
        string certId;
        string recipientName;
        string achievementTitle;
        uint256 timestamp;
        bool isValid;
    }

    // Mapping dari ID Sertifikat unik ke Data Sertifikat
    mapping(string => Certificate) public certificates;
    string[] public allCertIds;

    event CertificateMinted(
        string indexed certId,
        string recipientName,
        string achievementTitle,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Hanya pemilik kontrak yang berhak mencetak piagam");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Fungsi untuk menerbitkan sertifikat secara otomatis (bisa dipanggil backend/relayer)
     * @param certId ID Kanonikal unik per user (misal: TRQ-CERT-SORTING_MASTER-48291)
     * @param recipientName Nama lengkap user penerima
     * @param achievementTitle Judul pencapaian / quest
     */
    function mintCertificate(
        string memory certId,
        string memory recipientName,
        string memory achievementTitle
    ) external onlyOwner returns (bool) {
        require(!certificates[certId].isValid, "Sertifikat dengan ID ini sudah pernah diterbitkan");

        certificates[certId] = Certificate({
            certId: certId,
            recipientName: recipientName,
            achievementTitle: achievementTitle,
            timestamp: block.timestamp,
            isValid: true
        });

        allCertIds.push(certId);

        emit CertificateMinted(certId, recipientName, achievementTitle, block.timestamp);
        return true;
    }

    /**
     * @notice Memverifikasi keabsahan sertifikat secara on-chain
     */
    function verifyCertificate(string memory certId)
        external
        view
        returns (
            bool isValid,
            string memory recipientName,
            string memory achievementTitle,
            uint256 timestamp
        )
    {
        Certificate memory cert = certificates[certId];
        return (cert.isValid, cert.recipientName, cert.achievementTitle, cert.timestamp);
    }

    function totalCertificates() external view returns (uint256) {
        return allCertIds.length;
    }
}
