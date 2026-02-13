import 'package:flutter/material.dart';

import '../ui/debug_panel_shell.dart';
import 'debug_panel.dart';

/// 在应用 UI 之上叠加悬浮调试按钮与调试面板的根 Widget。
class DebugOverlayRoot extends StatefulWidget {
  const DebugOverlayRoot({
    super.key,
    required this.child,
    required this.controller,
  });

  final Widget child;
  final DebugPanelController controller;

  @override
  State<DebugOverlayRoot> createState() => _DebugOverlayRootState();
}

class _DebugOverlayRootState extends State<DebugOverlayRoot> {
  /// 悬浮按钮在屏幕中的位置，拖拽时更新。
  Offset _buttonPosition = const Offset(16, 120);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final buttonSize = 52.0;
        final padding = 12.0;

        // 将按钮位置限制在可视区域内。
        double clampX(double x) {
          final minX = padding;
          final maxX = constraints.maxWidth - buttonSize - padding;
          return x.clamp(minX, maxX);
        }

        double clampY(double y) {
          final minY = padding + media.padding.top;
          final maxY = constraints.maxHeight - buttonSize - padding - media.padding.bottom;
          return y.clamp(minY, maxY);
        }

        final adjustedPosition = Offset(
          clampX(_buttonPosition.dx),
          clampY(_buttonPosition.dy),
        );

        // DebugOverlayRoot 可能在 MaterialApp 之上，Stack 需要 Directionality 解析 alignment。
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              widget.child,
              Positioned(
                left: adjustedPosition.dx,
                top: adjustedPosition.dy,
                child: _buildDraggableButton(),
              ),
              // 面板在 MaterialApp 之上，需自提供 Theme + Localizations + Overlay，
              // 否则 Theme.of / TabBar / IconButton / Tooltip 等会报错。
              ValueListenableBuilder<bool>(
                valueListenable: widget.controller.panelVisible,
                builder: (context, visible, _) {
                  if (!visible) return const SizedBox.shrink();
                  return Theme(
                    data: ThemeData.light(useMaterial3: true),
                    child: Localizations(
                      locale: const Locale('en', 'US'),
                      delegates: const [
                        DefaultMaterialLocalizations.delegate,
                        DefaultWidgetsLocalizations.delegate,
                      ],
                      // FIX: 使用 Navigator 替代 Overlay，
                      // 因为 DropdownButton 内部需要 Navigator.push 来展示下拉菜单。
                      // Navigator 自身会创建 Overlay，满足所有子组件的需求。
                      // 使用 Navigator 替代 Overlay，
                      // 因为 DropdownButton 等组件内部需要 Navigator.push 来展示弹出菜单。
                      // Navigator 自身会创建 Overlay，满足所有子组件的需求。
                      child: Navigator(
                        onGenerateRoute: (_) => PageRouteBuilder(
                          opaque: false,
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder: (context, _, __) => DebugPanelShell(
                            onClose: widget.controller.hidePanel,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 可拖拽的悬浮按钮，点击打开/关闭面板。
  Widget _buildDraggableButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          _buttonPosition += details.delta;
        });
      },
      onTap: () => DebugPanel.togglePanel(),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(166),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.bug_report,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
