import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/event_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_constants.dart';
import '../../models/event_model.dart';
import '../admin/admin_events_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EventController>(context, listen: false).init();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Check if the current user is an admin
  bool _isAdmin(AuthController authController) {
    final user = authController.user;
    return user != null && (user.email.endsWith('@admin.com'));
  }
  
  // Show delete confirmation dialog
  void _confirmDeleteEvent(BuildContext context, EventController eventController, EventModel event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEvent(event);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(EventModel event) async {
    final scaffoldMsg = ScaffoldMessenger.of(context);
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Delete directly from Firestore
      await FirebaseFirestore.instance
          .collection(AppConstants.eventsCollection)
          .doc(event.id)
          .delete();
      
      // Refresh events
      await Provider.of<EventController>(context, listen: false).fetchEvents();
      
      // Show success message
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      scaffoldMsg.showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final eventController = Provider.of<EventController>(context);
    final authController = Provider.of<AuthController>(context);
    final isUserAdmin = _isAdmin(authController);
    
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: Text(
                  'Calender'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                pinned: true,
                floating: true,
                forceElevated: innerBoxIsScrolled,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.electricBlue,
                  labelColor: isDarkMode ? AppTheme.electricBlue : Colors.black87,
                  unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black54,
                  tabs: [
                    Tab(text: 'Events'.tr),
                    Tab(text: 'Lectures'.tr),
                  ],
                ),
                actions: [
                  // Admin action button for adding events
                  if (isUserAdmin)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add Event',
                        onPressed: () {
                          // Navigate with hero animation
                          Navigator.push(
                            context, 
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const AdminEventsScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(0.0, 1.0);
                                const end = Offset.zero;
                                const curve = Curves.easeOutQuint;
                                
                                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);
                                
                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Events tab - filter upcoming and past events by type "event"
              _buildEventsList(
                eventController.events.where((event) => event.type == 'event').toList(),
                'No events scheduled',
                isUserAdmin,
                eventController
              ),
              
              // Lectures tab - filter upcoming and past events by type "lecture"
              _buildEventsList(
                eventController.events.where((event) => event.type == 'lecture').toList(),
                'No lectures scheduled',
                isUserAdmin,
                eventController
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEventsList(List<EventModel> events, String emptyMessage, bool isAdmin, EventController eventController) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        // Add animation for each card
        return AnimatedEventCard(
          event: event, 
          isAdmin: isAdmin, 
          onDelete: _deleteEvent,
          index: index,
        );
      },
    );
  }
}

class AnimatedEventCard extends StatefulWidget {
  final EventModel event;
  final bool isAdmin;
  final Function(EventModel) onDelete;
  final int index;
  
  const AnimatedEventCard({
    super.key,
    required this.event,
    this.isAdmin = false,
    required this.onDelete,
    this.index = 0,
  });

  @override
  State<AnimatedEventCard> createState() => _AnimatedEventCardState();
}

class _AnimatedEventCardState extends State<AnimatedEventCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Offset animation for sliding in from bottom
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.2), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuint,
    ));
    
    // Opacity animation for fading in
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    // Stagger animation start time based on index
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: AppTheme.defaultElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Navigate to event details with hero animation
                  // Get.toNamed(AppConstants.eventDetailsRoute, arguments: widget.event);
                },
                splashColor: AppTheme.electricBlue.withOpacity(0.1),
                highlightColor: AppTheme.electricBlue.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Event content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date and time with admin delete button
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.electricBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.smallCornerRadius),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: AppTheme.electricBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.event.date.day}/${widget.event.date.month}/${widget.event.date.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.electricBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.mapsGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.smallCornerRadius),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: AppTheme.mapsGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.event.time,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.mapsGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Admin delete action
                              if (widget.isAdmin)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _confirmDelete(context),
                                    borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mapsRed.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppTheme.mapsRed,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Title
                          Text(
                            widget.event.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Description (limited)
                          Text(
                            widget.event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Location with map pin style
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.electricBlue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                              border: Border.all(
                                color: AppTheme.electricBlue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppTheme.electricBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.event.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.electricBlue,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppTheme.electricBlue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(widget.event);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}