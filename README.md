# Eonvera — Smart Contract (BELUM DILUNCURKAN)

Kontrak NFT untuk proyek **Eonvera** (https://eonvera.vercel.app), ditulis mengikuti konsep situsnya persis. Status: **sudah dikompilasi dan lolos 23/23 tes lokal — belum di-deploy ke jaringan mana pun.**

## Berkas

| Berkas | Isi |
| --- | --- |
| `contracts/Eonvera.sol` | Kontrak utama ERC-721 `Eonvera` (simbol `EONV`) |
| `contracts/mocks/MockAgentGate.sol` | Gate Agent ID contoh, HANYA untuk tes lokal — bukan untuk produksi |
| `contracts/mocks/AgentWallet.sol` | Dompet agen smart contract contoh, HANYA untuk tes lokal (membuktikan agen smart wallet bisa mint) — bukan untuk produksi |
| `test/Eonvera.t.sol` | 23 tes Foundry, termasuk uji habis (sold out) pada 3.333 mint penuh |
| `foundry.toml` | Konfigurasi Foundry (solc 0.8.24, optimizer 200 runs) |

## Kesesuaian dengan konsep situs

| Konsep di situs | Implementasi di kontrak |
| --- | --- |
| Satu seri, supply 3.333 | `MAX_SUPPLY = 3333` (konstanta, tidak bisa diubah), token ID 1–3333 |
| Mint khusus agent (Binance Agentic Wallet + Agent ID) | `mint()` hanya untuk alamat yang lolos gerbang agent: registry Agent ID eksternal (`agentGate`) dan/atau allowlist agent milik owner. Tidak ada jalur mint publik sama sekali. |
| Harga dibaca via `currentPrice()` | Fungsi `currentPrice()` persis seperti yang dipakai situs; `mint()` mewajibkan pembayaran BNB senilai tepat harga itu. **Harga resmi yang diputuskan owner (2026-11-03): 0,0003 BNB per karya** (300000000000000 wei) — diteruskan sebagai parameter konstruktor `mintPrice_` saat deploy nanti, dan owner masih bisa mengubahnya via `setMintPrice()` |
| Seed terkunci on-chain, "block-time seed" | Seed diturunkan dari data blok saat mint dan disimpan permanen di `workSeed[tokenId]` |
| Eon Engine: Rule 30/54/90/110/150/184, era Fractal/Complex/Chaos/Still, palet Signal Lime/Ember Field/Deep Tide | `workRule()`, `workEraName()`, `workPaletteName()` — fungsi murni dari seed, jadi situs/galeri/market selalu menurunkan gambar yang sama |
| Statistik "Minted 0 / 3,333", "Remaining" | `totalMinted()` / `totalSupply()` / `remaining()` |
| Roadmap Phase 03 — mint dibuka belakangan | Kontrak ter-deploy dalam keadaan **mint tertutup** (`mintOpen = false`); owner membukanya eksplisit lewat `setMintOpen(true)` |
| Market setelah mint | Transfer ERC-721 standar + royalti ERC-2981 (default 5% ke treasury, bisa diatur owner) |

Keputusan desain yang disengaja:

- **Tidak ada cek `tx.origin` / tipe akun.** Agentic wallet bisa berupa smart wallet, jadi identitas diverifikasi lewat gerbang Agent ID — bukan dengan menebak jenis akun pemanggil. Ini juga yang membuat kontrak bot biasa tetap tertolak: tanpa Agent ID, tidak bisa mint.
- **Pembayaran harus pas** (`msg.value == currentPrice()`), kelebihan/kekurangan ditolak. Agent membaca harga dulu dari `currentPrice()`, jadi tidak ada jalur refund yang bisa diserang.
- **Gate eksternal yang error tidak mengunci mint.** Jika registry Agent ID revert, kontrak jatuh kembali ke allowlist owner.
- **Seed hanya untuk karya seni** (rule/era/palet), tidak dipakai untuk pembayaran/akses/hadiah — keterbatasan prediktabilitas data blok didokumentasikan di kode.
- Pengaman standar: OpenZeppelin v5.1.0, `Pausable` untuk keadaan darurat, `ReentrancyGuard`, `withdraw()` hanya ke treasury.

## Cara menjalankan tes (lokal saja)

```bash
forge build
forge test
```

Hasil terakhir: **23 passed, 0 failed** — termasuk skenario: non-agent ditolak, agent allowlist & gate bisa mint, gate rusak → fallback allowlist, pembayaran salah ditolak, mint tertutup saat awal, pause menghentikan mint, withdraw masuk treasury, royalti 5%, dan mint ke-3.334 ditolak `SoldOut`.

## Yang HARUS diputuskan sebelum peluncuran (jangan deploy sebelum ini jelas)

1. **Alamat adapter registry Agent ID yang asli** untuk `setAgentGate(...)` — saat ini hanya ada mock untuk tes. Tanpa ini, gerbang berjalan hanya dari allowlist owner.
2. ~~Harga mint final~~ — **SUDAH DIPUTUSKAN (2026-11-03): 0,0003 BNB** (300000000000000 wei); rangkaian tes berjalan pada harga resmi ini.
3. **Base URI metadata** final (`baseURI_`, mis. IPFS) dan isi metadata per token.
4. ~~Alamat owner & treasury~~ — **SUDAH DIPUTUSKAN (2026-11-03)**, lihat `launch-params.md`: owner = wallet pribadi `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097`, treasury/revenue = Agentic Wallet `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7`.
5. **Audit keamanan independen** — tes lokal bukan pengganti audit.
6. Deploy ke **testnet BNB Chain (tBSC, chain ID 97)** dulu dan uji end-to-end dengan Agentic Wallet sebelum mainnet (chain ID 56).

> Tidak ada skrip deploy/broadcast yang disiapkan di repo ini, dan tidak ada kunci privat yang disimpan di sini — peluncuran adalah keputusan terpisah yang diambil manual setelah poin-poin di atas beres.
