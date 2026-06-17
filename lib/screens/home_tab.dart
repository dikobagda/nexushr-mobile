import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/leave_service.dart';
import '../services/attendance_service.dart';
import '../models/leave.dart';
import '../theme/app_theme.dart';

class HomeTab extends StatefulWidget {
  final Function(int)? onTabSelect;
  const HomeTab({super.key, this.onTabSelect});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final LeaveService _leaveService = LeaveService();
  final AttendanceService _attendanceService = AttendanceService();

  bool _isLoading = true;
  List<LeaveBalance> _leaveBalances = [];
  List<dynamic> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      // Fetch last 30 days of attendance
      final start = now.subtract(const Duration(days: 30));
      final startDateStr = DateFormat('yyyy-MM-dd').format(start);
      final endDateStr = DateFormat('yyyy-MM-dd').format(now);

      final results = await Future.wait([
        _leaveService.fetchBalances(user.id, now.year),
        _attendanceService.fetchMyLogs(startDate: startDateStr, endDate: endDateStr),
      ]);

      if (mounted) {
        setState(() {
          _leaveBalances = results[0] as List<LeaveBalance>;
          _recentLogs = results[1];
          // Sort logs descending by timestamp
          _recentLogs.sort((a, b) {
            final timeA = DateTime.parse(a['timestamp'] ?? a['Timestamp'] ?? DateTime.now().toIso8601String());
            final timeB = DateTime.parse(b['timestamp'] ?? b['Timestamp'] ?? DateTime.now().toIso8601String());
            return timeB.compareTo(timeA);
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[HomeTab] Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    String firstName = 'Employee';
    if (user?.name != null && user!.name.trim().isNotEmpty) {
      firstName = user.name.trim().split(' ').first;
    }

    return CustomScrollView(
      slivers: [
        // 1. Compact Header
        SliverAppBar(
          expandedHeight: 105.0,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                          color: Colors.white10,
                        ),
                        child: Center(
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'E',
                            style: GoogleFonts.inter(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text
                      Expanded(
                        child: Text(
                          '${_getGreeting()}\n$firstName',
                          style: GoogleFonts.inter(
                            fontSize: 15, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Logout
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(LucideIcons.logOut, color: Colors.white, size: 18),
                          onPressed: () => context.read<AuthService>().logout(),
                          tooltip: 'Sign Out',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Body
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Slideshow now inside body
                const HeaderSlideshow().animate().fade().slideY(begin: 0.05),
                
                const SizedBox(height: 32),

                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.inter(
                        fontSize: 18, 
                        fontWeight: FontWeight.w700, 
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Icon(LucideIcons.moreHorizontal, color: AppColors.textMuted, size: 20),
                  ],
                ).animate(delay: 100.ms).fade().slideX(begin: -0.05),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildPremiumQuickAction(
                      context, 
                      LucideIcons.fingerprint, 
                      'Clock In', 
                      AppColors.tealGradient, 
                      delay: 150,
                      onTap: () => widget.onTabSelect?.call(1),
                    ),
                    const SizedBox(width: 12),
                    _buildPremiumQuickAction(
                      context, 
                      LucideIcons.calendarPlus, 
                      'Time Off', 
                      AppColors.warningGradient, 
                      delay: 200,
                      onTap: () => widget.onTabSelect?.call(2),
                    ),
                    const SizedBox(width: 12),
                    _buildPremiumQuickAction(
                      context, 
                      LucideIcons.receipt, 
                      'Payslip', 
                      AppColors.primaryGradient, 
                      delay: 250,
                      onTap: () => widget.onTabSelect?.call(3),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Leave Balances
                _PremiumLeaveBalancesCard(
                  balances: _leaveBalances,
                  isLoading: _isLoading,
                ).animate(delay: 300.ms).fade().slideY(begin: 0.05),

                const SizedBox(height: 32),

                // Recent Attendance Timeline
                _RecentAttendanceTimeline(
                  logs: _recentLogs,
                  isLoading: _isLoading,
                ).animate(delay: 400.ms).fade().slideY(begin: 0.05),
                
                const SizedBox(height: 100), // Padding for bottom nav
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumQuickAction(
    BuildContext context, 
    IconData icon, 
    String label, 
    LinearGradient gradient, {
    int delay = 0,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04), 
                blurRadius: 15, 
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withOpacity(0.3), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w600, 
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ).animate(delay: Duration(milliseconds: delay)).fade().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class HeaderSlideshow extends StatefulWidget {
  const HeaderSlideshow({super.key});

  @override
  State<HeaderSlideshow> createState() => _HeaderSlideshowState();
}

class _HeaderSlideshowState extends State<HeaderSlideshow> {
  late final PageController _pageController;
  late final Timer _timer;
  int _currentPage = 0;

  final List<String> _banners = [
    'assets/images/banner_nexus.png',
    'assets/images/banner_collab.png',
    'assets/images/banner_wellness.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _banners.length,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _banners[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Center(
                            child: Icon(LucideIcons.image, size: 40, color: AppColors.primary),
                          ),
                        );
                      },
                    ),
                    // Gradient overlay to make it look premium
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            final isSelected = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isSelected ? 20 : 6,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PremiumLeaveBalancesCard extends StatelessWidget {
  final List<LeaveBalance> balances;
  final bool isLoading;

  const _PremiumLeaveBalancesCard({
    required this.balances,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leave Balances',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: isLoading
                ? [
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  ]
                : balances.isEmpty
                    ? [
                        Text(
                          'No leave balances found.',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        )
                      ]
                    : balances.take(3).map((bal) {
                        final label = bal.leaveType?.name ?? 'Leave';
                        final used = bal.usedDays.toInt();
                        final total = bal.totalDays.toInt();

                        // Assign color based on leave type code
                        Color color = const Color(0xFF06B6D4); // Cyan default
                        final code = bal.leaveType?.code.toUpperCase() ?? '';
                        if (code.contains('SICK')) {
                          color = const Color(0xFFF59E0B); // Orange
                        } else if (code.contains('ANNUAL') || code.contains('PERSONAL')) {
                          color = const Color(0xFF06B6D4); // Cyan
                        } else {
                          color = const Color(0xFF8B5CF6); // Purple
                        }

                        return _buildCircularProgress(label, used, total, color);
                      }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(String label, int used, int total, Color color) {
    final double progress = total > 0 ? (total - used) / total : 0;
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: color.withOpacity(0.1),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ).animate().custom(
                duration: 1.seconds,
                builder: (context, value, child) => CircularProgressIndicator(
                  value: progress * value,
                  strokeWidth: 8,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Center(
                child: Text(
                  '${total - used}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RecentAttendanceTimeline extends StatelessWidget {
  final List<dynamic> logs;
  final bool isLoading;

  const _RecentAttendanceTimeline({
    required this.logs,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Attendance',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'View All',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No recent attendance logs.',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...List.generate(logs.take(3).length, (index) {
              final log = logs[index];
              final type = (log['type'] ?? log['Type'] ?? '').toString().toLowerCase();
              final timestampStr = log['timestamp'] ?? log['Timestamp'] ?? '';
              final status = (log['status'] ?? log['Status'] ?? '').toString().toLowerCase();

              DateTime? parsedTime;
              if (timestampStr.isNotEmpty) {
                try {
                  parsedTime = DateTime.parse(timestampStr).toLocal();
                } catch (_) {}
              }

              String dayText = 'Unknown';
              String timeText = '--:--';
              if (parsedTime != null) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final yesterday = today.subtract(const Duration(days: 1));
                final logDate = DateTime(parsedTime.year, parsedTime.month, parsedTime.day);

                if (logDate == today) {
                  dayText = 'Today';
                } else if (logDate == yesterday) {
                  dayText = 'Yesterday';
                } else {
                  dayText = DateFormat('E, MMM d').format(parsedTime);
                }
                timeText = DateFormat('hh:mm a').format(parsedTime);
              }

              String statusText = 'Clock In';
              Color statusColor = const Color(0xFF10B981); // Green
              if (type == 'out') {
                statusText = 'Clock Out';
                statusColor = const Color(0xFFEF4444); // Red
              } else if (status == 'late') {
                statusText = 'Late';
                statusColor = const Color(0xFFF59E0B); // Orange
              } else if (status == 'ontime' || status == 'present') {
                statusText = 'On Time';
                statusColor = const Color(0xFF10B981); // Green
              }

              return _buildTimelineItem(
                dayText,
                timeText,
                statusText,
                statusColor,
                isFirst: index == 0,
                isLast: index == logs.take(3).length - 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String day, String time, String status, Color statusColor, {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  color: isFirst ? Colors.transparent : Colors.grey.withOpacity(0.2),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
