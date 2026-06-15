import SwiftUI

struct OverallCard: View {
    // Properti input dinamis agar komponen bisa digunakan kembali (Reusable)
    let title: String
    let status: String
    let description: String
    let iconName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // Baris Atas: Judul Teks & Ikon Indikator
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Text.Title2Regular) // Menggunakan token Headline Semibold Anda
                        .foregroundColor(.gray)
                    
                    Text(status)
                        .font(Text.TitleRegular)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Ikon Indikator (Menggunakan SF Symbols)
                Image(systemName: iconName)
                    .font(.system(size: 28)) // Ukuran ikon yang proporsional
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            // Baris Bawah: Deskripsi Analisis
            Text(description)
                .font(Text.CustomBody) // Menggunakan token Body Regular Anda
                .foregroundColor(.secondary)
                .lineLimit(nil) // Mengizinkan teks baris tak terbatas jika font membesar (HIG Compliant)
                .fixedSize(horizontal: false, vertical: true) // Mencegah teks terpotong secara vertikal
        }
        .padding(20) // Padding bagian dalam kartu (sesuai Figma padding 10-20)
        .frame(width: 259, alignment: .leading) // Kartu mengambil lebar maksimal layar
        .background(Color(.systemBackground)) // Mengikuti Light/Dark mode secara native
        .clipShape(RoundedRectangle(cornerRadius: Radius.OverallCard)) // Menggunakan Token Radius 25 Anda
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2) // Soft shadow minimalis
    }
}

#Preview {
    OverallCard(title: "Pace", status: "Too Fast", description: "You're speaking too quickly. Focus on pausing between sentences and key ideas to improve clarity.", iconName: AppIcon.paceGauge)
}
