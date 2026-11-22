import 'localization.dart';

import 'package:flutter/material.dart';

import 'royal_theme.dart';

class RoyalNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<NavigationDestination> destinations;
  const RoyalNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      heightFactor: 1,
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: EdgeInsets.fromLTRB(13, 0, 13, 10),
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xff19191e),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: royalLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .3),
                blurRadius: 22,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(destinations.length, (i) {
              final selected = i == selectedIndex, d = destinations[i];
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: d.label,
                  child: InkWell(
                    onTap: onDestinationSelected == null
                        ? null
                        : () => onDestinationSelected!(i),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 180),
                            width: 39,
                            height: 34,
                            decoration: BoxDecoration(
                              color: selected
                                  ? royalGold.withValues(alpha: .16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: royalGold.withValues(alpha: .1),
                                        blurRadius: 17,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: IconTheme(
                              data: IconThemeData(
                                size: 22,
                                color: selected ? royalGold : royalMuted,
                              ),
                              child: selected
                                  ? (d.selectedIcon ?? d.icon)
                                  : d.icon,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            tr(d.label),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? royalGold : royalMuted,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}
