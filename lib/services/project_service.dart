import 'dart:convert';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/model/project.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/model/attachment.dart';
import 'package:cnattendance/data/source/network/model/projectdetail/ProjectDetailResponse.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  /// Get project details by ID
  static Future<Project?> getProjectById(int projectId) async {
    try {
      print('🔍 Fetching project details for ID: $projectId');
      
      Preferences preferences = Preferences();
      var uri = Uri.parse(
          await preferences.getAppUrl() + Constant.PROJECT_DETAIL_URL + "/$projectId");

      String token = await preferences.getToken();
      bool isAd = await preferences.getEnglishDate();

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final projectResponse = ProjectDetailResponse.fromJson(responseData);

        // Convert to Project model (similar to ProjectDetailController logic)
        List<Member> members = [];
        for (var member in projectResponse.data.assigned_member) {
          members.add(Member(member.id, member.name, member.avatar, post: member.post));
        }

        List<Member> leaders = [];
        for (var leader in projectResponse.data.project_leader) {
          leaders.add(Member(leader.id, leader.name, leader.avatar, post: leader.post));
        }

        List<Attachment> attachments = [];
        for (var attachment in projectResponse.data.attachments) {
          if (attachment.type == "image") {
            attachments.add(Attachment(0, attachment.attachment_url, "image"));
          } else {
            attachments.add(Attachment(0, attachment.attachment_url, "file"));
          }
        }

        DateTime tempDate = DateFormat("yyyy-mm-dd").parse(projectResponse.data.start_date);
        String displayDate = isAd ? projectResponse.data.start_date : tempDate.toString();

        Project project = Project(
            projectResponse.data.id,
            projectResponse.data.name,
            projectResponse.data.slug,
            projectResponse.data.description,
            displayDate,
            projectResponse.data.priority,
            projectResponse.data.status,
            projectResponse.data.progress_percent,
            projectResponse.data.assigned_task_count,
            members,
            leaders,
            attachments);

        print('✅ Project fetched successfully: ${project.name}');
        return project;
      } else {
        print('❌ Failed to fetch project: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching project by ID: $e');
      return null;
    }
  }

  /// Get all projects and find one that matches the conversation name
  static Future<Project?> findProjectByConversationName(String conversationName) async {
    try {
      print('🔍 Finding project for conversation: $conversationName');
      
      // Extract project name from conversation name
      String projectName = conversationName
          .replaceAll(' Team Chat', '')
          .replaceAll(' Chat', '')
          .trim();
      
      print('📝 Extracted project name: $projectName');
      
      // Get all projects from dashboard endpoint
      final projects = await _getAllProjects();
      
      if (projects.isEmpty) {
        print('❌ No projects found');
        return null;
      }
      
      // Find project that matches the name (case-insensitive)
      final matchingProject = projects.firstWhere(
        (project) => project.name.toLowerCase() == projectName.toLowerCase(),
        orElse: () => throw Exception('Project not found for name: $projectName'),
      );
      
      print('✅ Found matching project: ${matchingProject.name} (ID: ${matchingProject.id})');
      
      // Get full project details
      return await getProjectById(matchingProject.id);
    } catch (e) {
      print('❌ Error finding project by conversation name: $e');
      return null;
    }
  }

  /// Get all projects from dashboard (simplified version)
  static Future<List<Project>> _getAllProjects() async {
    try {
      Preferences preferences = Preferences();
      var uri = Uri.parse(await preferences.getAppUrl() + Constant.PROJECT_DASHBOARD_URL);

      String token = await preferences.getToken();
      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == true && responseData['data'] != null) {
          final projectsData = responseData['data']['projects'] as List;
          
          List<Project> projects = [];
          for (var projectJson in projectsData) {
            // Create simplified project objects with basic info
            List<Member> members = [];
            if (projectJson['assigned_member'] != null) {
              for (var memberJson in projectJson['assigned_member']) {
                members.add(Member(
                  memberJson['id'] ?? 0,
                  memberJson['name'] ?? '',
                  memberJson['avatar'] ?? '',
                  post: memberJson['post'] ?? '',
                ));
              }
            }
            
            Project project = Project(
              projectJson['id'] ?? 0,
              projectJson['project_name'] ?? '',
              '', // slug not needed for matching
              '', // description not needed for matching
              projectJson['start_date'] ?? '',
              projectJson['priority'] ?? '',
              projectJson['status'] ?? '',
              projectJson['project_progress_percent'] ?? 0,
              projectJson['assigned_task_count'] ?? 0,
              members,
              [], // leaders not needed for initial matching
              [], // attachments not needed for initial matching
            );
            
            projects.add(project);
          }
          
          print('📊 Found ${projects.length} projects');
          return projects;
        }
      }
      
      print('❌ Failed to get projects from dashboard');
      return [];
    } catch (e) {
      print('❌ Error getting all projects: $e');
      return [];
    }
  }
}