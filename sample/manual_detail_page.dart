import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/keeper_category.dart';
import '../models/manual.dart';
import '../services/storage_service.dart';
import '../widgets/detail_row.dart';
import '../widgets/keeper_banner_ad.dart';
import 'edit_manual_page.dart';
import 'local_pdf_viewer_page.dart';

/// Keeperに保存されたアイテムの詳細画面です。
///
/// 主な責務は次のとおりです。
///
/// ・登録画像またはカテゴリー画像の表示
/// ・カテゴリー名と補足情報の表示
/// ・メーカー名、型番、URL、PDF、メモの表示
/// ・保存済みPDFを開く導線の表示
/// ・メモ写真の一覧表示
/// ・編集後の最新データを受け取り、詳細画面へ即時反映
///
/// 編集後もこの詳細画面に留まり、更新されたManualを画面内で保持するため、
/// StatefulWidgetとして実装します。
class ManualDetailPage extends StatefulWidget {
  const ManualDetailPage({super.key, required this.manual});

  /// Home画面から受け取った、詳細表示するKeeperアイテム
  final Manual manual;

  @override
  State<ManualDetailPage> createState() => _ManualDetailPageState();
}

class _ManualDetailPageState extends State<ManualDetailPage> {
  /// 現在、詳細画面へ表示しているKeeperアイテムです。
  ///
  /// 編集画面から更新済みManualが戻った場合は、この値を差し替えて
  /// 詳細画面全体を再描画します。
  late Manual currentManual;

  @override
  void initState() {
    super.initState();

    currentManual = widget.manual;
  }

  /// メモ写真をダイアログで拡大表示します。
  ///
  /// 写真はピンチ操作で拡大・縮小できます。
  /// 写真をタップするとダイアログを閉じます。
  Future<void> _showImagePreview(String storedPath) async {
    try {
      final resolution = await StorageService.resolveManualImage(storedPath);
      if (!mounted || !resolution.exists) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.file(resolution.file, fit: BoxFit.contain),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // 画像が見つからない場合はプレビューを開きません。
    }
  }

  /// 登録されているURLを端末のブラウザで開きます。
  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 登録されているWebページを開くためのURLカードを作成します。
  ///
  /// 長いURL文字列は直接表示せず、
  /// 利用者が押せることを分かりやすく伝える表示にします。
  Widget _buildUrlCard(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _openUrl(url);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '登録したWebページを開く',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// 編集画面を開きます。
  ///
  /// 編集が保存された場合は、更新済みManualを受け取ります。
  /// 詳細画面を閉じるのではなく、currentManualを更新することで
  /// タイトル、カテゴリー、メーカー名、型番などを即時反映します。
  Future<void> _openEditPage() async {
    final updatedManual = await Navigator.push<Manual>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return EditManualPage(manual: currentManual);
        },
      ),
    );

    if (!mounted || updatedManual == null) {
      return;
    }

    setState(() {
      currentManual = updatedManual;
    });
  }

  /// 詳細画面を閉じ、現在表示している最新のManualをHomeへ返します。
  ///
  /// 編集していない場合も同じManualを返すため、Home側は
  /// 詳細画面から戻ったあとに最新一覧を読み直せます。
  void _returnToHome() {
    Navigator.pop(context, currentManual);
  }

  @override
  Widget build(BuildContext context) {
    final category = keeperCategoryFromKey(currentManual.categoryKey);

    final memoImages = [
      currentManual.memoImagePath1,
      currentManual.memoImagePath2,
      currentManual.memoImagePath3,
    ].whereType<String>().where(_hasValue).toList();

    return PopScope<Manual>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _returnToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '戻る',
            onPressed: _returnToHome,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(currentManual.title),
          actions: [
            TextButton.icon(
              onPressed: _openEditPage,
              icon: Image.asset(
                'assets/icons/icons/edit.png',
                width: 28,
                height: 28,
              ),
              label: Text(
                '編集',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              // 通常表示より小さくならないよう、最小倍率を1倍に固定します。
              minScale: 1.0,

              // 詳細情報を最大3倍まで拡大できます。
              maxScale: 3.0,

              // 1本指の縦スクロールを優先するため、
              // InteractiveViewer側の移動操作は無効にします。
              panEnabled: false,

              // 2本指によるピンチ操作を有効にします。
              scaleEnabled: true,

              child: SizedBox(
                width: constraints.maxWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(category),
                      const SizedBox(height: 20),

                      Text(
                        currentManual.title,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontSize: 34, height: 1.2),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          _buildSmallCategoryImage(category),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _categoryLine(category),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(fontSize: 18),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      if (currentManual.usesProductTemplate) ...[
                        if (_hasValue(currentManual.maker))
                          DetailRow(label: 'メーカー名', value: currentManual.maker),
                        if (_hasValue(currentManual.model))
                          DetailRow(label: '型番', value: currentManual.model),
                      ] else if (_hasValue(currentManual.shortNote))
                        DetailRow(
                          label: 'ひとこと',
                          value: currentManual.shortNote,
                        ),

                      _buildPdfSection(context),

                      if (_hasValue(currentManual.sourceUrl))
                        _buildUrlCard(context, currentManual.sourceUrl!),

                      if (_hasValue(currentManual.memo))
                        DetailRow(label: 'メモ', value: currentManual.memo),

                      if (memoImages.isNotEmpty) ...[
                        const SizedBox(height: 20),

                        Text(
                          'メモ写真',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 18),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: List.generate(memoImages.length, (index) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < memoImages.length - 1 ? 8 : 0,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    _showImagePreview(memoImages[index]);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: FutureBuilder<ManualImageResolution>(
                                        future:
                                            StorageService.resolveManualImage(
                                              memoImages[index],
                                            ),
                                        builder: (context, snapshot) {
                                          final resolution = snapshot.data;

                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            );
                                          }

                                          if (snapshot.hasError ||
                                              resolution == null ||
                                              !resolution.exists) {
                                            return const Center(
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                            );
                                          }

                                          return Image.file(
                                            resolution.file,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: const KeeperBannerAd(),
      ),
    );
  }

  /// 保存済みPDFを開くボタンを表示します。
  ///
  /// PDFが未登録の場合は、ほかの未入力項目と同様に項目ごと非表示にします。
  /// PDFが登録されている場合は、端末内に保存したPDFを
  /// Keeper内のPDFビューアーで開くためのボタンを表示します。
  Widget _buildPdfSection(BuildContext context) {
    final pdfPath = currentManual.pdfPath;

    if (pdfPath == null || pdfPath.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final pdfFileName = StorageService.displayFileName(pdfPath);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF', style: Theme.of(context).textTheme.labelLarge),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    pdfFileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                  ),
                ),

                const SizedBox(width: 8),

                TextButton(
                  onPressed: () {
                    _openPdf(context, pdfPath);
                  },
                  child: Text(
                    'マニュアルを開く',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Keeperが端末内へ保存したPDFを表示します。
  void _openPdf(BuildContext context, String pdfPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return LocalPdfViewerPage(
            pdfPath: pdfPath,
            title: currentManual.title,
            manualId: currentManual.id,
          );
        },
      ),
    );
  }

  /// 画面上部のヘッダーを構築します。
  ///
  /// 登録画像がある場合はその画像を表示します。
  /// 画像がない場合や読み込みに失敗した場合は、
  /// Keeperオリジナルのカテゴリー画像へ切り替えます。
  Widget _buildHeader(KeeperCategory category) {
    final storedPath = currentManual.imagePath;

    if (storedPath == null || storedPath.trim().isEmpty) {
      return _categoryHeader(category);
    }

    return FutureBuilder<ManualImageResolution>(
      future: StorageService.resolveManualImage(storedPath),
      builder: (context, snapshot) {
        final resolution = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: double.infinity,
            height: 180,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        if (snapshot.hasError || resolution == null || !resolution.exists) {
          return _categoryHeader(category);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            resolution.file,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) {
              return _categoryHeader(category);
            },
          ),
        );
      },
    );
  }

  /// 登録画像がない場合に表示するカテゴリー画像ヘッダーです。
  ///
  /// アセットの読み込みに失敗した場合は、
  /// 移行期間用のMaterial Iconへ自動的に切り替えます。
  Widget _categoryHeader(KeeperCategory category) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: Center(
        child: Image.asset(
          category.iconPath,
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(category.icon, size: 88);
          },
        ),
      ),
    );
  }

  /// カテゴリー名の横に表示する小さなカテゴリー画像です。
  Widget _buildSmallCategoryImage(KeeperCategory category) {
    return Image.asset(
      category.iconPath,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(category.icon, size: 20);
      },
    );
  }

  /// 画面へ表示するカテゴリー名を返します。
  ///
  /// My Keeperでユーザーが自由カテゴリー名を入力している場合は、
  /// 固定名の「My Keeper」ではなく、その自由カテゴリー名を表示します。
  ///
  /// 固定カテゴリーではcustomCategoryNameが空文字のため、
  /// keeperCategory側のカテゴリー名を表示します。
  String _displayCategoryName(KeeperCategory category) {
    final customCategoryName = currentManual.customCategoryName.trim();

    if (customCategoryName.isNotEmpty) {
      return customCategoryName;
    }

    return category.name;
  }

  /// カテゴリー名と補足情報を1行にまとめます。
  ///
  /// 製品テンプレートではメーカー名、
  /// 一般テンプレートでは「ひとこと」を補足として表示します。
  String _categoryLine(KeeperCategory category) {
    final categoryName = _displayCategoryName(category);

    final detail =
        (currentManual.usesProductTemplate
                ? currentManual.maker
                : currentManual.shortNote)
            .trim();

    if (detail.isEmpty) {
      return categoryName;
    }

    return '$categoryName / $detail';
  }

  /// null・空文字・空白だけの値を、詳細画面へ出さないための共通判定です。
  bool _hasValue(String? value) => value?.trim().isNotEmpty ?? false;
}
