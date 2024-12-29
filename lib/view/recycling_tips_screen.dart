import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:recycle_riti/api/rest_auth.dart';
import 'package:recycle_riti/utils/exception_handling.dart';
import 'package:recycle_riti/utils/theme.dart';
import 'package:recycle_riti/view/notification_screen.dart';
import 'package:recycle_riti/widgets/custom_app_bar.dart';
import 'package:recycle_riti/widgets/custom_button.dart';

class RecyclingTipsScreen extends StatefulWidget {
  const RecyclingTipsScreen({super.key});

  @override
  State<RecyclingTipsScreen> createState() => _RecyclingTipsScreenState();
}

class _RecyclingTipsScreenState extends State<RecyclingTipsScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  String? _currentUsername;
  List<dynamic> _blogs = [];
  List<dynamic> _filteredBlogs = [];
  final List<String> _categories = ["Plastic", "Paper", "Glass", "Electronics", "Organic"];
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _fetchUserDataAndBlogs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScreen.initNotifications(
        context,
        onNotificationReceived: () {
          setState(() {});
          print('RecyclingTipsScreen: Notification received, refreshing UI');
        },
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    NotificationScreen.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDataAndBlogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getUserProfile(),
      defaultErrorMessage: 'Failed to fetch user profile',
      onSuccess: (data) {
        setState(() {
          _currentUserId = data['user']['id']?.toString();
          _currentUsername = data['user']['username'] ?? 'User';
        });
        print('RecyclingTipsScreen: Fetched user profile - UserId: $_currentUserId, Username: $_currentUsername');
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
        });
        print('RecyclingTipsScreen: Error fetching user profile: $error');
      },
    );

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.getEducationalContent(),
      defaultErrorMessage: 'Failed to fetch recycling tips',
      onSuccess: (data) {
        setState(() {
          _blogs = (data['contents'] ?? []).where((blog) => blog['status'] == 'approved').toList();
          _filteredBlogs = _blogs;
        });
        print('RecyclingTipsScreen: Fetched ${_blogs.length} approved blogs');
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
        });
        print('RecyclingTipsScreen: Error fetching blogs: $error');
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  void _filterBlogs() {
    setState(() {
      _filteredBlogs = _blogs.where((blog) {
        final matchesTitle = blog['title']
            .toString()
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());
        final matchesCategory = _selectedCategory == null || blog['category'] == _selectedCategory;
        return matchesTitle && matchesCategory;
      }).toList();
    });
  }

  Future<void> _uploadBlog({Map<String, dynamic>? existingBlog}) async {
    final TextEditingController titleController =
        TextEditingController(text: existingBlog?['title'] ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: existingBlog?['content'] ?? '');
    String? selectedCategory = existingBlog?['category'] ?? _categories.first;
    File? imageFile;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingBlog != null ? "Edit Recycling Tip" : "Share a Recycling Tip",
                style: AppTheme.sectionTitleStyle.copyWith(color: AppTheme.textColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: "Title",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: _categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setDialogState(() {
                            imageFile = File(pickedFile.path);
                          });
                        }
                      },
                      color: AppTheme.primaryColor,
                      child: Text(
                        existingBlog != null && imageFile == null
                            ? "Change Image"
                            : "Pick Image",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (imageFile != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "Image Selected: ${imageFile!.path.split('/').last}",
                        style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
                      ),
                    ],
                    if (existingBlog != null && existingBlog['imageUrl'] != null && imageFile == null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "Current Image: ${existingBlog['imageUrl'].split('/').last}",
                        style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        descriptionController.text.trim().isEmpty ||
                        selectedCategory == null) {
                      ExceptionHandling.showSnackBar(context, 'Please fill all fields');
                      return;
                    }

                    if (existingBlog != null) {
                      await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
                        context,
                        () => AuthService.updateEducationalContent(
                          id: existingBlog['id'].toString(),
                          title: titleController.text.trim(),
                          content: descriptionController.text.trim(),
                          category: selectedCategory,
                          imageFile: imageFile,
                        ),
                        defaultErrorMessage: 'Failed to update blog',
                        onSuccess: (data) {
                          Navigator.pop(context);
                          ExceptionHandling.showSnackBar(context, 'Blog updated and pending admin approval');
                          _fetchUserDataAndBlogs();
                          print('RecyclingTipsScreen: Blog updated successfully, pending approval');
                        },
                        onError: (error) {
                          print('RecyclingTipsScreen: Error updating blog: $error');
                        },
                      );
                    } else {
                      await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
                        context,
                        () => AuthService.createEducationalContent(
                          title: titleController.text.trim(),
                          content: descriptionController.text.trim(),
                          category: selectedCategory!,
                          imageFile: imageFile,
                        ),
                        defaultErrorMessage: 'Failed to upload blog',
                        onSuccess: (data) {
                          Navigator.pop(context);
                          ExceptionHandling.showSnackBar(context, 'Blog uploaded and pending admin approval');
                          _fetchUserDataAndBlogs();
                          print('RecyclingTipsScreen: Blog uploaded successfully, pending approval');
                        },
                        onError: (error) {
                          print('RecyclingTipsScreen: Error uploading blog: $error');
                        },
                      );
                    }
                  },
                  child: Text(
                    existingBlog != null ? "Update" : "Submit",
                    style: const TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBlog(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this blog post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ExceptionHandling.handleApiCall<Map<String, dynamic>>(
      context,
      () => AuthService.deleteEducationalContent(id),
      defaultErrorMessage: 'Failed to delete blog',
      onSuccess: (data) {
        ExceptionHandling.showSnackBar(context, 'Blog deleted successfully');
        _fetchUserDataAndBlogs();
        print('RecyclingTipsScreen: Blog deleted successfully');
      },
      onError: (error) {
        print('RecyclingTipsScreen: Error deleting blog: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Recycling Tips",
        isAgentScreen: false,
        showNotifications: true,
        onNotificationStateChanged: () {
          setState(() {});
          print('RecyclingTipsScreen: Notification state changed, refreshing UI');
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _uploadBlog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor,
              AppTheme.primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: AppTheme.bodyTextStyle.copyWith(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          onPressed: _fetchUserDataAndBlogs,
                          color: AppTheme.primaryColor,
                          child: const Text(
                            "Retry",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05,
                        vertical: 20,
                      ),
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 600),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              _buildHeaderSection(),
                              const SizedBox(height: 16),
                              _buildSearchAndFilterSection(),
                              const SizedBox(height: 24),
                              _buildBlogList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.accentColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Explore Recycling Tips",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Learn and share tips to recycle better and contribute to a greener planet!",
                    style: AppTheme.bodyTextStyle.copyWith(
                      fontSize: 16,
                      color: AppTheme.textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.lightbulb_outline,
              size: 40,
              color: AppTheme.accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: "Search by Title",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                  suffixIcon: _isSearchActive
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.secondaryTextColor),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _isSearchActive = false;
                              _filterBlogs();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _isSearchActive = value.isNotEmpty;
                    _filterBlogs();
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _selectedCategory != null ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    String? tempCategory = _selectedCategory;
                    return AlertDialog(
                      title: const Text("Filter by Category"),
                      content: StatefulBuilder(
                        builder: (context, setDialogState) {
                          return DropdownButton<String>(
                            value: tempCategory,
                            isExpanded: true,
                            hint: const Text("Select Category"),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text("All Categories"),
                              ),
                              ..._categories.map((category) => DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  )),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                tempCategory = value;
                              });
                            },
                          );
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _filterBlogs();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Apply"),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        if (_selectedCategory != null || _isSearchActive) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedCategory != null)
                Chip(
                  label: Text(
                    "Category: $_selectedCategory",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  deleteIcon: const Icon(Icons.clear, color: Colors.white),
                  onDeleted: () {
                    setState(() {
                      _selectedCategory = null;
                      _filterBlogs();
                    });
                  },
                ),
              if (_isSearchActive) const SizedBox(width: 8),
              if (_isSearchActive)
                Chip(
                  label: Text(
                    "Search: ${_searchController.text}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  deleteIcon: const Icon(Icons.clear, color: Colors.white),
                  onDeleted: () {
                    setState(() {
                      _searchController.clear();
                      _isSearchActive = false;
                      _filterBlogs();
                    });
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBlogList() {
    if (_filteredBlogs.isEmpty) {
      return Center(
        child: Text(
          "No recycling tips available. Be the first to share one!",
          style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredBlogs.length,
      itemBuilder: (context, index) {
        final blog = _filteredBlogs[index];
        final title = blog['title'] ?? 'Untitled';
        final content = blog['content'] ?? '';
        final category = blog['category'] ?? 'General';
        final imageUrl = blog['imageUrl'] as String?;
        final username = blog['user']?['username'] ?? 'Anonymous';
        final createdAt = blog['createdAt'] != null ? DateTime.parse(blog['createdAt']) : DateTime.now();
        final isOwner = blog['user']?['id']?.toString() == _currentUserId;

        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: AppTheme.bodyTextStyle.copyWith(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                              onPressed: () => _uploadBlog(existingBlog: blog),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteBlog(blog['id'].toString()),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: '${AuthService.baseUrl.replaceAll('/api', '')}$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    content.length > 100 ? '${content.substring(0, 100)}...' : content,
                    style: AppTheme.bodyTextStyle.copyWith(color: AppTheme.textColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "By: $username",
                        style: AppTheme.bodyTextStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(createdAt),
                        style: AppTheme.bodyTextStyle.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}