# Eonvera — Parameter Peluncuran (Launch Params)

Dicatat dari keputusan owner. **Kontrak BELUM di-deploy** — file ini hanya parameter resmi yang akan dipakai saat owner memutuskan launch.

| Parameter | Nilai | Status |
| --- | --- | --- |
| Jaringan | BNB Chain mainnet (chain ID 56) | Diputuskan |
| Harga mint (`mintPrice_`) | 0,0003 BNB (300000000000000 wei) | Diputuskan 2026-11-03 |
| Owner (`initialOwner`) | `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097` (wallet pribadi owner) | Diputuskan 2026-11-03 |
| Treasury / revenue (`treasury_`) | `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7` (Agentic Wallet) | Diputuskan 2026-11-03 |
| Royalti default | 5% (500 bps) ke treasury | Bawaan kontrak, bisa diatur owner |
| Base URI metadata (`baseURI_`) | — | BELUM diputuskan |
| Agent gate (`agentGate`) | — (sementara allowlist owner) | BELUM diputuskan — menunggu adapter registry Agent ID asli |

Verifikasi alamat (3 Nov 2026, dibaca dari BSC mainnet):
- Kedua alamat valid checksum EIP-55 dan terdaftar di BSC sebagai akun biasa (tanpa kode kontrak) — aman sebagai owner maupun penerima revenue.
- Saldo wallet owner saat dicatat: ±0,00118 BNB (± Rp15.000) — cukup untuk estimasi deploy ±0,00012 BNB (± Rp1.500, di bawah budget Rp3.000) plus transaksi admin pembuka.
- Saldo Agentic Wallet saat dicatat: ±0,000156 BNB (± Rp1.987).

Urutan saat launch nanti (setelah owner menyetujui):
1. Deploy `Eonvera(owner, treasury, 300000000000000, baseURI)` dari wallet owner.
2. Verifikasi source code di BscScan (gratis).
3. `setAgentGate(<adapter Agent ID>)` bila adapter sudah ada; dan/atau `setAgentsAllowed(...)` untuk agent pertama.
4. Uji satu mint percobaan.
5. `setMintOpen(true)` — mint resmi dibuka (Roadmap Phase 03).
