import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants.dart';
import '../services/lost_dog_service.dart';
import '../widgets/lost_dog/help_find_tab.dart';
import '../widgets/lost_dog/missing_dogs_tab.dart';

class LostDogHubScreen extends ConsumerStatefulWidget {
  const LostDogHubScreen({super.key});

  @override
  ConsumerState<LostDogHubScreen> createState() => _LostDogHubScreenState();
}

class _LostDogHubScreenState extends ConsumerState<LostDogHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lostDogSvc = ref.read(lostDogServiceProvider);
    final activeCount = lostDogSvc.activeLostCount;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, color: Colors.amber.shade300, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Lost Dog Network',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Missing Dogs'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Help Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MissingDogsTab(
            lostDogSvc: lostDogSvc,
            onChanged: () => setState(() {}),
          ),
          HelpFindTab(lostDogSvc: lostDogSvc),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lost-dog/report'),
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.pets, color: Colors.black87),
        label: const Text(
          'Report Lost Dog',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
