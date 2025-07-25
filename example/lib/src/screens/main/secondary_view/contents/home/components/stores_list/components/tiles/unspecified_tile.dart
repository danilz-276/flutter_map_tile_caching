import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';

import '../../../../../../../../../shared/misc/internal_store_read_write_behaviour.dart';
import '../../../../../../../../../shared/state/general_provider.dart';
import 'store_tile/components/browse_store_strategy_selector/browse_store_strategy_selector.dart';

class UnspecifiedTile extends StatefulWidget {
  const UnspecifiedTile({
    super.key,
    required this.useCompactLayout,
  });

  final bool useCompactLayout;

  @override
  State<UnspecifiedTile> createState() => _UnspecifiedTileState();
}

class _UnspecifiedTileState extends State<UnspecifiedTile> {
  @override
  Widget build(BuildContext context) {
    final isAllUnselectedDisabled = context
                .select<GeneralProvider, InternalBrowseStoreStrategy?>(
                  (p) => p.currentStores['(unspecified)'],
                )
                ?.toBrowseStoreStrategy() ==
            null ||
        context.select<GeneralProvider, BrowseLoadingStrategy>(
              (p) => p.loadingStrategy,
            ) ==
            BrowseLoadingStrategy.onlineFirst;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          title: const Text(
            'All unspecified',
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          subtitle: const Text('(matching URL)'),
          leading: const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.unpublished, size: 28),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Use as fallback only',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceDim,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.last_page),
                        Switch.adaptive(
                          value: !isAllUnselectedDisabled &&
                              context.select<GeneralProvider, bool>(
                                (provider) =>
                                    provider.useUnspecifiedAsFallbackOnly,
                              ),
                          onChanged: isAllUnselectedDisabled
                              ? null
                              : (v) {
                                  context
                                      .read<GeneralProvider>()
                                      .useUnspecifiedAsFallbackOnly = v;
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(width: 2),
                BrowseStoreStrategySelector(
                  storeName: '(unspecified)',
                  enabled: true,
                  inheritable: false,
                  useCompactLayout: widget.useCompactLayout,
                ),
                if (widget.useCompactLayout) const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
