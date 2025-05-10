import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/event_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedEventType = 'event'; // Default to 'event'

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuint),
    );

    // Start animation
    _animationController.forward();

    // Make sure events are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventController = Provider.of<EventController>(
        context,
        listen: false,
      );
      if (eventController.events.isEmpty) {
        eventController.init();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.electricBlue),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.electricBlue),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    return DateFormat.jm().format(dateTime);
  }

  Future<void> _addEvent() async {
    if (_formKey.currentState!.validate()) {
      final eventController = Provider.of<EventController>(
        context,
        listen: false,
      );

      // Show loading indicator
      setState(() {
        _isSubmitting = true;
      });

      final success = await eventController.addEventAdmin(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        time: _formatTimeOfDay(_selectedTime),
        location: _locationController.text.trim(),
        type: _selectedEventType,
        context: context,
      );

      // Hide loading indicator
      setState(() {
        _isSubmitting = false;
      });

      if (success && mounted) {
        // Reset form without showing success animation
        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        setState(() {
          _selectedDate = DateTime.now().add(const Duration(days: 1));
          _selectedTime = TimeOfDay.now();
          _selectedEventType = 'event';
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventController.error ?? 'Failed to add event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final eventController = Provider.of<EventController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Event'),
        elevation: AppTheme.defaultElevation,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.smallCornerRadius),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkNavy : Colors.white,
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Form title
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Create New Event',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDarkMode
                                        ? Colors.white
                                        : AppTheme.darkNavy,
                              ),
                            ),
                          ),

                          // Event Type Selection
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Event Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDarkMode
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.cornerRadius,
                                    ),
                                    border: Border.all(
                                      color:
                                          isDarkMode
                                              ? Colors.white24
                                              : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Event Option
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedEventType = 'event';
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _selectedEventType == 'event'
                                                      ? AppTheme.electricBlue
                                                          .withOpacity(0.2)
                                                      : Colors.transparent,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(
                                                  AppTheme.cornerRadius - 1,
                                                ),
                                                bottomLeft: Radius.circular(
                                                  AppTheme.cornerRadius - 1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.event,
                                                  color:
                                                      _selectedEventType ==
                                                              'event'
                                                          ? AppTheme
                                                              .electricBlue
                                                          : (isDarkMode
                                                              ? Colors.white54
                                                              : Colors.grey),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Event',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        _selectedEventType ==
                                                                'event'
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                    color:
                                                        _selectedEventType ==
                                                                'event'
                                                            ? AppTheme
                                                                .electricBlue
                                                            : (isDarkMode
                                                                ? Colors.white54
                                                                : Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Lecture Option
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedEventType = 'lecture';
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _selectedEventType ==
                                                          'lecture'
                                                      ? AppTheme.electricBlue
                                                          .withOpacity(0.2)
                                                      : Colors.transparent,
                                              borderRadius: BorderRadius.only(
                                                topRight: Radius.circular(
                                                  AppTheme.cornerRadius - 1,
                                                ),
                                                bottomRight: Radius.circular(
                                                  AppTheme.cornerRadius - 1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.school,
                                                  color:
                                                      _selectedEventType ==
                                                              'lecture'
                                                          ? AppTheme
                                                              .electricBlue
                                                          : (isDarkMode
                                                              ? Colors.white54
                                                              : Colors.grey),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Lecture',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        _selectedEventType ==
                                                                'lecture'
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                    color:
                                                        _selectedEventType ==
                                                                'lecture'
                                                            ? AppTheme
                                                                .electricBlue
                                                            : (isDarkMode
                                                                ? Colors.white54
                                                                : Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Title Field
                          CustomTextField(
                            controller: _titleController,
                            label: 'Title',
                            hint: 'Enter event title',
                            prefixIcon: Icons.title,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description field
                          CustomTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Enter event description',
                            prefixIcon: Icons.description,
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Location field
                          CustomTextField(
                            controller: _locationController,
                            label: 'Location',
                            hint: 'Enter event location',
                            prefixIcon: Icons.location_on,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a location';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Date and time selectors
                          Row(
                            children: [
                              // Date picker
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectDate(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.cornerRadius,
                                      ),
                                      border: Border.all(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color:
                                              isDarkMode
                                                  ? Colors.white70
                                                  : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_selectedDate),
                                          style: TextStyle(
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Time picker
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.cornerRadius,
                                      ),
                                      border: Border.all(
                                        color:
                                            isDarkMode
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color:
                                              isDarkMode
                                                  ? Colors.white70
                                                  : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimeOfDay(_selectedTime),
                                          style: TextStyle(
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Submit button
                          Center(
                            child: CustomButton(
                              text: 'Create Event',
                              onPressed: _isSubmitting ? null : _addEvent,
                              isLoading: _isSubmitting,
                              isFullWidth: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
