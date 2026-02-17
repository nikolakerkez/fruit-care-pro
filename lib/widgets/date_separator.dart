import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DateSeparator extends StatelessWidget {
  final Timestamp? timestamp;

  const DateSeparator({super.key, this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();

    final date = timestamp!.toDate();
    final formattedDate = _formatDate(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey[400],
              thickness: 1,
              endIndent: 12,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey[400],
              thickness: 1,
              indent: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Danas';
    } else if (messageDate == yesterday) {
      return 'Juče';
    } else if (now.difference(messageDate).inDays < 7) {
      // Prikaži dan u nedelji
      return _getDayName(date.weekday);
    } else if (date.year == now.year) {
      // Iste godine - prikaži samo dan i mesec
      return '${date.day}. ${_getMonthName(date.month)}';
    } else {
      // Različite godine - prikaži kompletan datum
      return '${date.day}. ${_getMonthName(date.month)} ${date.year}.';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Ponedeljak';
      case 2:
        return 'Utorak';
      case 3:
        return 'Sreda';
      case 4:
        return 'Četvrtak';
      case 5:
        return 'Petak';
      case 6:
        return 'Subota';
      case 7:
        return 'Nedelja';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'januar';
      case 2:
        return 'februar';
      case 3:
        return 'mart';
      case 4:
        return 'april';
      case 5:
        return 'maj';
      case 6:
        return 'jun';
      case 7:
        return 'jul';
      case 8:
        return 'avgust';
      case 9:
        return 'septembar';
      case 10:
        return 'oktobar';
      case 11:
        return 'novembar';
      case 12:
        return 'decembar';
    }
    return "";
  }
}
