import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens lấy trực tiếp từ `:root` của LT-ARC-Web-UI_1.html và
/// LT-ARC-Mobile-UI_1.html (đã duyệt 01/09/2026) — xem plan §6.2.
/// Web và mobile KHÔNG dùng chung 1 ThemeData vì bo góc/tông nền khác nhau
/// trong 2 bản UI gốc.
///
/// LƯU Ý MIGRATION: các hằng số `web*`/`webDark*` dưới đây là NGUỒN GIÁ TRỊ
/// gốc — trang đã chuyển sang theme động (đọc qua [LtArcColors]) không nên
/// tham chiếu trực tiếp các hằng số này nữa, chỉ giữ lại cho ~33 trang Web
/// chưa migrate (xem kế hoạch 4 giai đoạn — Giai đoạn 3).
class AppColors {
  AppColors._();

  static const gold = Color(0xFFB6924F);

  // Web — bản sáng "Đá travertine ấm", lấy trực tiếp từ `:root[data-theme="light"]`
  // của LT-ARC-Web-UI_3.html (đã duyệt) — dùng làm nguồn giá trị cho LtArcColors.light().
  // Ý tưởng riêng (không phải bản kem/trắng LT-ARC-Web-UI_1.html cũ nữa).
  static const webBackground = Color(0xFFECE7DB);
  static const webForeground = Color(0xFF2A241D);
  static const webSidebar = Color(0xFF1B1916);
  static const webSidebarText = Color(0xFFC9C0AE);
  static const webBorder = Color(0xFFDDD5C2);

  /// Badge/stat semantic tokens.
  static const webCardBg = Color(0xFFFFFFFF);
  static const webCardGradBottom = Color(0xFFF6F1E6);
  static const webMutedFg = Color(0xFF6B6152);
  static const webSecondaryBg = Color(0xFFE2DAC5);
  static const webSecondaryFg = Color(0xFF362F24);
  static const webMutedBg = Color(0xFFF3EEE2);
  static const webDestructive = Color(0xFFA8402F);
  static const webSuccess = Color(0xFF457058);
  static const webWarning = Color(0xFF8A5C1A);
  static const webWarningFg = Color(0xFF2A1A08);
  static const webAccent = Color(0xFFE7DFC9);
  /// Vàng đồng riêng cho theme sáng Web — KHÁC [gold] (tông tối hơn, dùng chung
  /// cho Mobile + sidebar Web, không đổi theo bản LT-ARC-Web-UI_3.html này).
  static const webGold = Color(0xFFB6905C);
  static const webGoldBright = Color(0xFFD1A869);
  static const webGoldDeep = Color(0xFFAC8651);

  // Mobile (LT-ARC-Mobile-UI_1.html)
  static const mobileBackground = Color(0xFFF1F2F4);
  static const mobileForeground = Color(0xFF181A1F);
  static const mobileDarkCard = Color(0xFF16181D);
  static const mobileBorder = Color(0xFFEBECEF);

  /// Web — bản phối màu trầm/bóng cao cấp, lấy trực tiếp từ `:root` của
  /// `LT-ARC-Web-UI_3.html` (đã duyệt). Nguồn giá trị cho LtArcColors.dark().
  static const webDarkBg = Color(0xFF15110B);
  static const webDarkCardTop = Color(0xFF251D12);
  static const webDarkCardBottom = Color(0xFF1A140C);
  static const webDarkBorder = Color(0xFF372C1A);
  static const webDarkFg = Color(0xFFF1E7D3);
  static const webDarkMutedFg = Color(0xFFB3A37F);
  static const webDarkMuted = Color(0xFF23190F);
  static const webDarkAccent = Color(0xFF2C2013);
  static const webDarkSecondaryBg = Color(0xFF291F13);
  static const webDarkSecondaryFg = Color(0xFFE9DEC2);
  static const webDarkGold = Color(0xFFC9A15A);
  static const webDarkGoldBright = Color(0xFFECD096);
  static const webDarkGoldDeep = Color(0xFF8A6A34);
  static const webDarkGoldOnFill = Color(0xFF1C160C);
  static const webDarkSuccess = Color(0xFF7FA473);
  static const webDarkSuccessFg = Color(0xFF16210F);
  static const webDarkWarning = Color(0xFFD1A052);
  static const webDarkWarningFg = Color(0xFF241A09);
  static const webDarkDestructive = Color(0xFFC17862);
  static const webDarkDestructiveFg = Color(0xFF2A1310);

  // Sidebar — CỐ Ý giữ tông than ở cả sáng/tối (mỏ neo thương hiệu, xem
  // LT-ARC-Web-UI_3.html comment). Không đưa vào LtArcColors vì không đổi
  // theo theme.
  static const webDarkSidebarBg = Color(0xFF0C0A06);
  static const webDarkSidebarBorder = Color(0xFF241C10);
  static const webDarkSidebarText = Color(0xFFB7A685);
  static const webDarkSidebarTextStrong = Color(0xFFF5EAD2);
  static const webDarkSidebarMuted = Color(0xFF7C6C4D);
  static const webDarkSidebarActiveBg = Color(0xFF221A0E);
  static const webDarkSidebarActiveFg = Color(0xFFEFD8A0);
}

/// Token ngữ nghĩa theo theme — tương ứng biến CSS `--bg/--fg/--card/...`
/// trong LT-ARC-Web-UI_3.html. Đọc qua `Theme.of(context).extension<LtArcColors>()!`
/// thay vì tham chiếu thẳng [AppColors] khi trang đã migrate sang theme động.
class LtArcColors extends ThemeExtension<LtArcColors> {
  const LtArcColors({
    required this.bg,
    required this.fg,
    required this.card,
    required this.cardGradTop,
    required this.cardGradBottom,
    required this.primary,
    required this.primaryFg,
    required this.secondary,
    required this.secondaryFg,
    required this.muted,
    required this.mutedFg,
    required this.accent,
    required this.destructive,
    required this.destructiveFg,
    required this.destructiveSoft,
    required this.destructiveBorder,
    required this.success,
    required this.successFg,
    required this.successSoft,
    required this.successBorder,
    required this.warning,
    required this.warningFg,
    required this.warningSoft,
    required this.warningBorder,
    required this.border,
    required this.gold,
    required this.goldBright,
    required this.goldDeep,
    required this.shadowAmbient,
    required this.shadowAmbientSoft,
  });

  final Color bg;
  final Color fg;
  final Color card;
  final Color cardGradTop;
  final Color cardGradBottom;
  final Color primary;
  final Color primaryFg;
  final Color secondary;
  final Color secondaryFg;
  final Color muted;
  final Color mutedFg;
  final Color accent;
  final Color destructive;
  final Color destructiveFg;
  final Color destructiveSoft;
  final Color destructiveBorder;
  final Color success;
  final Color successFg;
  final Color successSoft;
  final Color successBorder;
  final Color warning;
  final Color warningFg;
  final Color warningSoft;
  final Color warningBorder;
  final Color border;
  final Color gold;
  final Color goldBright;
  final Color goldDeep;
  final Color shadowAmbient;
  final Color shadowAmbientSoft;

  factory LtArcColors.light() => LtArcColors(
        bg: AppColors.webBackground,
        fg: AppColors.webForeground,
        card: AppColors.webCardBg,
        cardGradTop: AppColors.webCardBg,
        cardGradBottom: AppColors.webCardGradBottom,
        primary: AppColors.webGold,
        primaryFg: AppColors.webForeground,
        secondary: AppColors.webSecondaryBg,
        secondaryFg: AppColors.webSecondaryFg,
        muted: AppColors.webMutedBg,
        mutedFg: AppColors.webMutedFg,
        accent: AppColors.webAccent,
        destructive: AppColors.webDestructive,
        destructiveFg: Colors.white,
        destructiveSoft: AppColors.webDestructive.withValues(alpha: 0.10),
        destructiveBorder: AppColors.webDestructive.withValues(alpha: 0.35),
        success: AppColors.webSuccess,
        successFg: Colors.white,
        successSoft: AppColors.webSuccess.withValues(alpha: 0.11),
        successBorder: AppColors.webSuccess.withValues(alpha: 0.35),
        warning: AppColors.webWarning,
        warningFg: AppColors.webWarningFg,
        warningSoft: AppColors.webWarning.withValues(alpha: 0.15),
        warningBorder: AppColors.webWarning.withValues(alpha: 0.38),
        border: AppColors.webBorder,
        gold: AppColors.webGold,
        goldBright: AppColors.webGoldBright,
        goldDeep: AppColors.webGoldDeep,
        shadowAmbient: const Color(0x292A241D),
        shadowAmbientSoft: const Color(0x172A241D),
      );

  factory LtArcColors.dark() => LtArcColors(
        bg: AppColors.webDarkBg,
        fg: AppColors.webDarkFg,
        card: AppColors.webDarkCardTop,
        cardGradTop: AppColors.webDarkCardTop,
        cardGradBottom: AppColors.webDarkCardBottom,
        primary: AppColors.webDarkGold,
        primaryFg: AppColors.webDarkGoldOnFill,
        secondary: AppColors.webDarkSecondaryBg,
        secondaryFg: AppColors.webDarkSecondaryFg,
        muted: AppColors.webDarkMuted,
        mutedFg: AppColors.webDarkMutedFg,
        accent: AppColors.webDarkAccent,
        destructive: AppColors.webDarkDestructive,
        destructiveFg: AppColors.webDarkDestructiveFg,
        destructiveSoft: AppColors.webDarkDestructive.withValues(alpha: 0.16),
        destructiveBorder: AppColors.webDarkDestructive.withValues(alpha: 0.4),
        success: AppColors.webDarkSuccess,
        successFg: AppColors.webDarkSuccessFg,
        successSoft: AppColors.webDarkSuccess.withValues(alpha: 0.16),
        successBorder: AppColors.webDarkSuccess.withValues(alpha: 0.4),
        warning: AppColors.webDarkWarning,
        warningFg: AppColors.webDarkWarningFg,
        warningSoft: AppColors.webDarkWarning.withValues(alpha: 0.16),
        warningBorder: AppColors.webDarkWarning.withValues(alpha: 0.4),
        border: AppColors.webDarkBorder,
        gold: AppColors.webDarkGold,
        goldBright: AppColors.webDarkGoldBright,
        goldDeep: AppColors.webDarkGoldDeep,
        shadowAmbient: const Color(0xA6000000),
        shadowAmbientSoft: const Color(0x66000000),
      );

  @override
  LtArcColors copyWith({
    Color? bg,
    Color? fg,
    Color? card,
    Color? cardGradTop,
    Color? cardGradBottom,
    Color? primary,
    Color? primaryFg,
    Color? secondary,
    Color? secondaryFg,
    Color? muted,
    Color? mutedFg,
    Color? accent,
    Color? destructive,
    Color? destructiveFg,
    Color? destructiveSoft,
    Color? destructiveBorder,
    Color? success,
    Color? successFg,
    Color? successSoft,
    Color? successBorder,
    Color? warning,
    Color? warningFg,
    Color? warningSoft,
    Color? warningBorder,
    Color? border,
    Color? gold,
    Color? goldBright,
    Color? goldDeep,
    Color? shadowAmbient,
    Color? shadowAmbientSoft,
  }) {
    return LtArcColors(
      bg: bg ?? this.bg,
      fg: fg ?? this.fg,
      card: card ?? this.card,
      cardGradTop: cardGradTop ?? this.cardGradTop,
      cardGradBottom: cardGradBottom ?? this.cardGradBottom,
      primary: primary ?? this.primary,
      primaryFg: primaryFg ?? this.primaryFg,
      secondary: secondary ?? this.secondary,
      secondaryFg: secondaryFg ?? this.secondaryFg,
      muted: muted ?? this.muted,
      mutedFg: mutedFg ?? this.mutedFg,
      accent: accent ?? this.accent,
      destructive: destructive ?? this.destructive,
      destructiveFg: destructiveFg ?? this.destructiveFg,
      destructiveSoft: destructiveSoft ?? this.destructiveSoft,
      destructiveBorder: destructiveBorder ?? this.destructiveBorder,
      success: success ?? this.success,
      successFg: successFg ?? this.successFg,
      successSoft: successSoft ?? this.successSoft,
      successBorder: successBorder ?? this.successBorder,
      warning: warning ?? this.warning,
      warningFg: warningFg ?? this.warningFg,
      warningSoft: warningSoft ?? this.warningSoft,
      warningBorder: warningBorder ?? this.warningBorder,
      border: border ?? this.border,
      gold: gold ?? this.gold,
      goldBright: goldBright ?? this.goldBright,
      goldDeep: goldDeep ?? this.goldDeep,
      shadowAmbient: shadowAmbient ?? this.shadowAmbient,
      shadowAmbientSoft: shadowAmbientSoft ?? this.shadowAmbientSoft,
    );
  }

  @override
  LtArcColors lerp(ThemeExtension<LtArcColors>? other, double t) {
    if (other is! LtArcColors) return this;
    return LtArcColors(
      bg: Color.lerp(bg, other.bg, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardGradTop: Color.lerp(cardGradTop, other.cardGradTop, t)!,
      cardGradBottom: Color.lerp(cardGradBottom, other.cardGradBottom, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryFg: Color.lerp(primaryFg, other.primaryFg, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryFg: Color.lerp(secondaryFg, other.secondaryFg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedFg: Color.lerp(mutedFg, other.mutedFg, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveFg: Color.lerp(destructiveFg, other.destructiveFg, t)!,
      destructiveSoft: Color.lerp(destructiveSoft, other.destructiveSoft, t)!,
      destructiveBorder: Color.lerp(destructiveBorder, other.destructiveBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      border: Color.lerp(border, other.border, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldBright: Color.lerp(goldBright, other.goldBright, t)!,
      goldDeep: Color.lerp(goldDeep, other.goldDeep, t)!,
      shadowAmbient: Color.lerp(shadowAmbient, other.shadowAmbient, t)!,
      shadowAmbientSoft: Color.lerp(shadowAmbientSoft, other.shadowAmbientSoft, t)!,
    );
  }
}

/// Helper — lấy [LtArcColors] hiện tại, dùng ở mọi widget đã migrate.
extension LtArcColorsContext on BuildContext {
  LtArcColors get colors => Theme.of(this).extension<LtArcColors>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData mobile() {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.montserratTextTheme(),
      scaffoldBackgroundColor: AppColors.mobileBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        primary: AppColors.mobileDarkCard,
        secondary: AppColors.gold,
        surface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.mobileBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.mobileForeground,
        elevation: 0,
      ),
    );
  }

  static ThemeData _webBase({required Brightness brightness, required LtArcColors colors}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      textTheme: GoogleFonts.montserratTextTheme(brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.gold,
        brightness: brightness,
        primary: colors.gold,
        onPrimary: colors.primaryFg,
        secondary: colors.gold,
        surface: colors.card,
        onSurface: colors.fg,
        error: colors.destructive,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerColor: colors.border,
      iconTheme: IconThemeData(color: colors.mutedFg),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: colors.mutedFg),
        dataTextStyle: TextStyle(fontSize: 13, color: colors.fg),
        dividerThickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.gold),
      extensions: [colors],
    );
    return base.copyWith(textTheme: base.textTheme.apply(bodyColor: colors.fg, displayColor: colors.fg));
  }

  static ThemeData webLight() => _webBase(brightness: Brightness.light, colors: LtArcColors.light());

  static ThemeData webDark() => _webBase(brightness: Brightness.dark, colors: LtArcColors.dark());
}
