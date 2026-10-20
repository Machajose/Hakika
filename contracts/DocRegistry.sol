// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DocRegistry
 * @notice A public "notebook" that stores ONLY document fingerprints (hashes).
 *         No names, grades or personal data are ever stored here.
 *
 * Who can write?  Only approved "issuers" (e.g. the MUT registrar's service wallet).
 * Who can read?   Anyone in the world, for free.
 */
contract DocRegistry {
    struct Record {
        uint64 issuedAt;   // block timestamp when the fingerprint was recorded (0 = never recorded)
        uint64 revokedAt;  // 0 = still valid
        address issuer;    // which approved wallet recorded it
    }

    address public owner;
    mapping(address => bool) public isIssuer;
    mapping(bytes32 => Record) private records;

    event IssuerChanged(address indexed issuer, bool allowed);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Anchored(bytes32 indexed docHash, address indexed issuer, uint64 issuedAt);
    event Revoked(bytes32 indexed docHash, address indexed by, uint64 revokedAt);

    error NotOwner();
    error NotIssuer();
    error AlreadyAnchored(bytes32 docHash);
    error NotFound(bytes32 docHash);
    error AlreadyRevoked(bytes32 docHash);
    error EmptyBatch();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyIssuer() {
        if (!isIssuer[msg.sender]) revert NotIssuer();
        _;
    }

    constructor() {
        owner = msg.sender;
        isIssuer[msg.sender] = true;
        emit IssuerChanged(msg.sender, true);
    }

    // ---------- Admin (the "who is allowed to write" part) ----------

    function setIssuer(address issuer, bool allowed) external onlyOwner {
        if (issuer == address(0)) revert ZeroAddress();
        isIssuer[issuer] = allowed;
        emit IssuerChanged(issuer, allowed);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ---------- Writing ----------

    /// @notice Record one document fingerprint.
    function anchor(bytes32 docHash) external onlyIssuer {
        _anchor(docHash);
    }

    /// @notice Record many fingerprints in one transaction (e.g. a whole graduating class).
    function anchorBatch(bytes32[] calldata docHashes) external onlyIssuer {
        if (docHashes.length == 0) revert EmptyBatch();
        for (uint256 i = 0; i < docHashes.length; i++) {
            _anchor(docHashes[i]);
        }
    }

    /// @notice Mark a document as no longer valid (error, reissue, fraud). The history stays visible.
    function revoke(bytes32 docHash) external onlyIssuer {
        Record storage r = records[docHash];
        if (r.issuedAt == 0) revert NotFound(docHash);
        if (r.revokedAt != 0) revert AlreadyRevoked(docHash);
        r.revokedAt = uint64(block.timestamp);
        emit Revoked(docHash, msg.sender, r.revokedAt);
    }

    // ---------- Reading (free for everyone) ----------

    /// @return exists    true if this fingerprint was ever recorded
    /// @return revoked   true if it was recorded and later revoked
    /// @return issuedAt  unix time it was recorded (0 if not found)
    /// @return revokedAt unix time it was revoked (0 if not revoked)
    /// @return issuer    wallet that recorded it
    function verify(bytes32 docHash)
        external
        view
        returns (bool exists, bool revoked, uint64 issuedAt, uint64 revokedAt, address issuer)
    {
        Record memory r = records[docHash];
        exists = r.issuedAt != 0;
        revoked = r.revokedAt != 0;
        issuedAt = r.issuedAt;
        revokedAt = r.revokedAt;
        issuer = r.issuer;
    }

    // ---------- Internal ----------

    function _anchor(bytes32 docHash) internal {
        if (records[docHash].issuedAt != 0) revert AlreadyAnchored(docHash);
        uint64 nowTs = uint64(block.timestamp);
        records[docHash] = Record({issuedAt: nowTs, revokedAt: 0, issuer: msg.sender});
        emit Anchored(docHash, msg.sender, nowTs);
    }
}
