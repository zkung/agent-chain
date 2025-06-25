package crypto

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"

	"agent-chain/pkg/types"
)

// KeyPair represents a public/private key pair
type KeyPair struct {
	PrivateKey *ecdsa.PrivateKey
	PublicKey  *ecdsa.PublicKey
}

// GenerateKeyPair generates a new ECDSA key pair
func GenerateKeyPair() (*KeyPair, error) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}

	return &KeyPair{
		PrivateKey: privateKey,
		PublicKey:  &privateKey.PublicKey,
	}, nil
}

// GetAddress derives address from public key
func (kp *KeyPair) GetAddress() types.Address {
	pubKeyBytes := append(kp.PublicKey.X.Bytes(), kp.PublicKey.Y.Bytes()...)
	hash := sha256.Sum256(pubKeyBytes)

	var addr types.Address
	copy(addr[:], hash[12:]) // Take last 20 bytes
	return addr
}

// Sign signs data with private key
func (kp *KeyPair) Sign(data []byte) ([]byte, error) {
	hash := sha256.Sum256(data)
	r, s, err := ecdsa.Sign(rand.Reader, kp.PrivateKey, hash[:])
	if err != nil {
		return nil, err
	}

	// Encode signature as r||s
	signature := append(r.Bytes(), s.Bytes()...)
	return signature, nil
}

// VerifySignature verifies signature against public key
func VerifySignature(pubKey *ecdsa.PublicKey, data, signature []byte) bool {
	if len(signature) != 64 {
		return false
	}

	hash := sha256.Sum256(data)
	r := new(big.Int).SetBytes(signature[:32])
	s := new(big.Int).SetBytes(signature[32:])

	return ecdsa.Verify(pubKey, hash[:], r, s)
}

// PublicKeyFromBytes reconstructs public key from bytes
func PublicKeyFromBytes(data []byte) (*ecdsa.PublicKey, error) {
	if len(data) != 64 {
		return nil, fmt.Errorf("invalid public key length: %d", len(data))
	}

	x := new(big.Int).SetBytes(data[:32])
	y := new(big.Int).SetBytes(data[32:])

	pubKey := &ecdsa.PublicKey{
		Curve: elliptic.P256(),
		X:     x,
		Y:     y,
	}

	return pubKey, nil
}

// PublicKeyToBytes converts public key to bytes
func PublicKeyToBytes(pubKey *ecdsa.PublicKey) []byte {
	return append(pubKey.X.Bytes(), pubKey.Y.Bytes()...)
}

// PrivateKeyToHex converts private key to hex string
func (kp *KeyPair) PrivateKeyToHex() string {
	return hex.EncodeToString(kp.PrivateKey.D.Bytes())
}

// PrivateKeyFromHex reconstructs private key from hex string
func PrivateKeyFromHex(hexKey string) (*KeyPair, error) {
	keyBytes, err := hex.DecodeString(hexKey)
	if err != nil {
		return nil, err
	}

	privateKey := &ecdsa.PrivateKey{
		PublicKey: ecdsa.PublicKey{
			Curve: elliptic.P256(),
		},
		D: new(big.Int).SetBytes(keyBytes),
	}

	privateKey.PublicKey.X, privateKey.PublicKey.Y = privateKey.PublicKey.Curve.ScalarBaseMult(keyBytes)

	return &KeyPair{
		PrivateKey: privateKey,
		PublicKey:  &privateKey.PublicKey,
	}, nil
}

// Hash256 computes SHA256 hash
func Hash256(data []byte) types.Hash {
	return sha256.Sum256(data)
}

// AddressFromString parses address from hex string
func AddressFromString(s string) (types.Address, error) {
	var addr types.Address

	// Remove 0x prefix if present
	if len(s) >= 2 && s[:2] == "0x" {
		s = s[2:]
	}

	if len(s) != 40 {
		return addr, fmt.Errorf("invalid address length: %d", len(s))
	}

	bytes, err := hex.DecodeString(s)
	if err != nil {
		return addr, err
	}

	copy(addr[:], bytes)
	return addr, nil
}

// HashFromString parses hash from hex string
func HashFromString(s string) (types.Hash, error) {
	var hash types.Hash

	if len(s) != 64 {
		return hash, fmt.Errorf("invalid hash length: %d", len(s))
	}

	bytes, err := hex.DecodeString(s)
	if err != nil {
		return hash, err
	}

	copy(hash[:], bytes)
	return hash, nil
}
