import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../shared/state/download_configuration_provider.dart';
import '../../../../../shared/state/region_selection_provider.dart';
import '../../../../../shared/state/selected_tab_state.dart';
import '../../layouts/side/components/panel.dart';
import 'components/config_options/config_options.dart';
import 'components/confirmation_panel/confirmation_panel.dart';

class DownloadConfigurationViewSide extends StatelessWidget {
  const DownloadConfigurationViewSide({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Theme.of(context).colorScheme.surface,
              ),
              padding: const EdgeInsets.all(4),
              child: IconButton(
                onPressed: () {
                  final regionSelectionProvider =
                      context.read<RegionSelectionProvider>();
                  final downloadConfigProvider =
                      context.read<DownloadConfigurationProvider>();

                  regionSelectionProvider.isDownloadSetupPanelVisible = false;

                  if (downloadConfigProvider.fromRecovery == null) return;

                  regionSelectionProvider.clearConstructedRegions();
                  downloadConfigProvider.fromRecovery = null;

                  selectedTabState.value = 2;
                },
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Return to selection',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: SideViewPanel(
              autoPadding: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ConfigOptions(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SideViewPanel(child: ConfirmationPanel()),
          const SizedBox(height: 16),
        ],
      );
}
