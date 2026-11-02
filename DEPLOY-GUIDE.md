# Panduan Deploy Eonvera ke BNB Chain Mainnet

Semua persiapan sudah selesai dan terverifikasi. Langkah satu-satunya yang harus dilakukan dari wallet Anda sendiri adalah **menandatangani transaksi deploy** — tidak ada siapa pun (termasuk asisten AI mana pun) yang boleh meminta seed phrase / private key Anda. Jangan pernah membagikannya.

## Angka yang sudah dicek ulang (3 Nov 2026, ±01:29 WIB)

| Hal | Nilai |
| --- | --- |
| Jaringan | BNB Chain mainnet, chain ID **56** |
| Harga gas jaringan saat dicek | **0,05 gwei** (dibaca langsung dari RPC BSC) |
| Gas deploy terukur (versi final) | 2.383.851 gas |
| Estimasi biaya deploy | **± 0,00012 BNB (± Rp1.500)** — di bawah budget Rp3.000 |
| Saldo wallet owner saat dicek | 0,001179 BNB (± Rp15.000) — cukup untuk deploy + transaksi admin awal |

## Parameter konstruktor (salin persis)

| Parameter | Nilai |
| --- | --- |
| `initialOwner` | `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097` |
| `treasury_` | `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7` |
| `mintPrice_` | `300000000000000` |
| `baseURI_` | *(kosongkan dulu — diatur setelah deploy via `setBaseURI`, sebelum mint dibuka)* |

## Langkah deploy via Remix (dari HP/PC Anda)

Gunakan file **`Eonvera.flat.sol`** (satu file utuh, tanpa import — memang disiapkan untuk ini).

1. Buka **https://remix.ethereum.org** (pastikan domain ini persis).
2. Di panel File, buat file baru bernama `Eonvera.flat.sol`, lalu tempel seluruh isi file `Eonvera.flat.sol`.
3. Buka tab **Solidity Compiler**: pilih versi **0.8.24**, aktifkan **optimization 200 runs** (di bagian Advanced Configurations), lalu klik **Compile Eonvera.flat.sol**.
4. Buka tab **Deploy & Run Transactions**:
   - Environment: **Injected Provider** → hubungkan wallet owner Anda (Binance Wallet / MetaMask).
   - Pastikan jaringan wallet = **BNB Smart Chain (56)** dan alamat yang terhubung = `0x0262...4097`.
   - Di daftar **Contract**, pilih **Eonvera** (bukan kontrak OpenZeppelin yang ikut terbawa di file).
5. Di kolom parameter deploy, isi 4 nilai dari tabel di atas persis, lalu klik **Deploy / Transact**.
6. Wallet akan menampilkan estimasi gas (±2,37 juta gas, ±0,00012 BNB). Periksa lagi alamat owner & treasury di layar konfirmasi, lalu **Confirm**.
7. Setelah sukses, Remix menampilkan alamat kontrak baru (diawali `0x...`). **Kirimkan alamat kontrak itu ke saya** — saya verifikasi datanya di BscScan dan lanjutkan langkah pasca-deploy bersama Anda.

## Setelah deploy (tetap dari wallet owner, dibantu panduan saya)

1. **Verifikasi source code di BscScan** (gratis): upload file flat yang sama, compiler 0.8.24, optimizer 200 runs.
2. Daftarkan Agentic Wallet sebagai agent pertama: `setAgentAllowed(0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7, true)`.
3. Atur metadata bila sudah siap: `setBaseURI(<uri metadata final>)`.
4. **JANGAN** panggil `setMintOpen(true)` dulu — kontrak ter-deploy dalam keadaan mint tertutup, dan membukanya adalah keputusan terpisah saat semua sudah siap.
5. Opsional: satu mint percobaan dari Agentic Wallet untuk memastikan alur ujung-ke-ujung berjalan di mainnet.

## Peringatan keamanan

- Deploy hanya dari **remix.ethereum.org** resmi dan wallet Anda sendiri.
- Cocokkan alamat owner & treasury **karakter pertama dan terakhir** sebelum Confirm — transaksi deploy tidak bisa dibatalkan.
- Siapa pun yang meminta seed phrase/private key dengan alasan “membantu deploy” adalah penipuan. Tanda tangan selalu Anda lakukan sendiri di aplikasi wallet Anda.
