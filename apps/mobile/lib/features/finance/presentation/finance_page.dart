import 'package:flutter/material.dart';

import '../../overhead/presentation/overhead_allocation_tab.dart';
import '../../reports/presentation/cashflow_tab.dart';
import '../../reports/presentation/profit_loss_tab.dart';

/// FR-8/11/12 — Tài chính: Tổng quan & P&L | Chi phí chung | Quỹ & Dòng tiền
/// (đúng plan §6.1).
class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tài chính'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Tổng quan & P&L'), Tab(text: 'Chi phí chung'), Tab(text: 'Quỹ & Dòng tiền')],
          ),
        ),
        body: const TabBarView(
          children: [ProfitLossTab(), OverheadAllocationTab(), CashflowTab()],
        ),
      ),
    );
  }
}
