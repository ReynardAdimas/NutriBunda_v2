import 'package:flutter/material.dart';

class KesanPesanPage extends StatelessWidget {
  const KesanPesanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kesan & Pesan TPM'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              context, 
              icon: Icons.favorite_rounded, 
              iconColor: const Color(0xFFE53935), 
              label: 'Kesan', 
              content: "Sangat Menyenangkan he..he.."
            ), 
            const SizedBox(height: 16,), 
            _buildCard(
              context, 
              icon: Icons.chat_bubble_rounded, 
              iconColor: const Color(0xFF1E88E5), 
              label: 'Pesan', 
              content: "Semoga kelas Teknologi dan Pemrograman Mobile lebih menantang lagi"
            ), 
          ],
        ),
      ) 
    );
  
  } 
  Widget _buildCard(
    BuildContext context, {
      required IconData icon, 
      required Color iconColor, 
      required String label, 
      required String content,
    }
  ) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor,size: 20,),
                ),
                const SizedBox(height: 12,), 
                Text(
                  label, 
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87
                  ),
                )
              ],
            ), 
            const SizedBox(height: 12,), 
            const Divider(height: 1, color: Color(0xFFEEEEEE),), 
            const SizedBox(height: 12,), 
            Text(
              content, 
              style: const TextStyle(
                fontSize: 14, 
                color: Colors.black54, 
                height: 1.6
              ),
            )
          ],
        ),
      ),
    );
  }
}