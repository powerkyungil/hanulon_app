import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_radii.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme_palette.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          navigationShell,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 132,
            child: _BottomNavigationFade(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          0,
          AppSpacing.space4,
          AppSpacing.space3,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.floatingNavigation),
            border: Border.all(color: palette.cardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.shadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.floatingNavigation),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '홈',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.schedule_outlined),
                    selectedIcon: Icon(Icons.schedule_rounded),
                    label: '일정',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.how_to_vote_outlined),
                    selectedIcon: Icon(Icons.how_to_vote_rounded),
                    label: '투표',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    selectedIcon: Icon(Icons.menu_open_rounded),
                    label: '전체',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationFade extends StatelessWidget {
  const _BottomNavigationFade();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              palette.backgroundBottom.withValues(
                alpha: palette.isDark ? 0.08 : 0.04,
              ),
              palette.backgroundBottom.withValues(
                alpha: palette.isDark ? 0.26 : 0.16,
              ),
            ],
            stops: const <double>[0, 0.58, 1],
          ),
        ),
      ),
    );
  }
}
