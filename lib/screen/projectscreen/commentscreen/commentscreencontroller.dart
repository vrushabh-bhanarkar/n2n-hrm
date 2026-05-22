import 'dart:convert';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/commentlist/commentlistresponse.dart';
import 'package:cnattendance/data/source/network/model/commentsaveresponse/commentsaveresponse.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/model/comment.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/model/mention.dart';
import 'package:cnattendance/model/reply.dart';
import 'package:cnattendance/model/sendcomment.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mentions/flutter_mentions.dart' as FM;
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class CommentScreenController extends GetxController {
  TextEditingController commentEdit = new TextEditingController();
  final scrollController = ScrollController();
  Preferences preferences = Preferences();
  var focusNode = FocusNode();

  var user = User(
          id: 0,
          name: "",
          email: "",
          username: "",
          avatar: "",
          workspace_type: "0")
      .obs;

  var sendComment = SendComment();

  var taskId = "0";
  var commentController = TextEditingController();
  var commentId = 0.obs;

  int PAGE = 1;
  static const int PER_PAGE =
      10; // Changed from 10000 to 10 for proper pagination
  var hasMoreComments = true.obs; // Track if there are more comments to load

  final mentionList = <Member>[].obs;

  void onReplyClicked(String replyId) {
    if (commentId.value.toString() != replyId) {
      commentId.value = int.parse(replyId);
      focusNode.requestFocus();
    } else {
      commentId.value = 0;
      focusNode.unfocus();
    }
  }

  var commentList = <Comment>[].obs;

  GlobalKey<FM.FlutterMentionsState> commentKey =
      GlobalKey<FM.FlutterMentionsState>();

  @override
  Future<void> onInit() async {
    super.onInit();
    taskId = Get.arguments["taskId"];
    user.value = await preferences.getUser();
    getComments();
  }

  Future<void> getComments([double position = 0]) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() +
        Constant.GET_COMMENT_URL +
        "?per_page=$PER_PAGE&page=$PAGE&task_id=" +
        Get.arguments["taskId"]);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    log(uri.toString());

    EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black);
    final response = await http.get(
      uri,
      headers: headers,
    );
    EasyLoading.dismiss(animation: true);
    log(response.body.toString());

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      final value = CommentListResponse.fromJson(responseData);

      var comments = <Comment>[];
      for (var comment in value.data) {
        var commentMentions = <Mention>[];
        for (var mention in comment.mentioned) {
          commentMentions.add(Mention(mention.id.toString(), mention.name));
        }
        var replies = <Reply>[];
        for (var reply in comment.replies) {
          var mentions = <Mention>[];
          for (var mention in reply.mentioned) {
            mentions.add(Mention(mention.id.toString(), mention.name));
          }
          replies.add(Reply(
              reply.reply_id,
              reply.comment_id,
              reply.description,
              reply.created_by_name,
              reply.created_by_id.toString(),
              reply.avatar,
              reply.created_at,
              mentions));
        }
        comments.add(Comment(
            comment.id,
            comment.description,
            comment.created_by_name,
            comment.created_by_id.toString(),
            comment.avatar,
            comment.created_at,
            commentMentions,
            replies));
      }
      if (PAGE == 1) {
        commentList.value = comments;
      } else {
        commentList.addAll(comments);
      }

      if (comments.isNotEmpty) {
        PAGE++;
        hasMoreComments.value =
            comments.length >= PER_PAGE; // More comments if we got a full page
      } else {
        hasMoreComments.value = false; // No more comments
      }

      scrollController.jumpTo(position);
    } else {
      var errorMessage = responseData['message'];
      print(errorMessage);
      throw errorMessage;
    }
  }

  Future<void> saveComments() async {
    if (commentController.text.isEmpty) {
      return;
    }
    Preferences preferences = Preferences();
    var uri =
        Uri.parse(await preferences.getAppUrl() + Constant.SAVE_COMMENT_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    log(uri.toString());
    final body = {
      "task_id": taskId,
      "comment_id":
          commentId.value.toString() == "0" ? "" : commentId.value.toString(),
      "description": commentController.text
    };

    for (int i = 0; i < mentionList.length; i++) {
      body.addEntries({"mentioned[$i]": mentionList[i].id.toString()}.entries);
    }
    final response = await http.post(uri, headers: headers, body: body);

    log(response.body.toString());

    final responseData = json.decode(response.body);

    final bool isSuccess =
      response.statusCode == 200 && responseData['status'] == true;

    // Check if the response was successful
    if (isSuccess) {
      final comment = commentsaveresponse.fromJson(responseData);

      commentController.clear();
      commentId.value = 0;
      mentionList.clear();

      if (hasComment(comment.data.id)) {
        for (var oldComment in commentList) {
          if (oldComment.id == comment.data.id) {
            var commentMentions = <Mention>[];
            for (var mention in comment.data.mentioned) {
              commentMentions.add(Mention(mention.id.toString(), mention.name));
            }
            var replies = <Reply>[];
            for (var reply in comment.data.replies) {
              var mentions = <Mention>[];
              for (var mention in reply.mentioned) {
                mentions.add(Mention(mention.id.toString(), mention.name));
              }
              replies.add(Reply(
                  reply.reply_id,
                  reply.comment_id,
                  reply.description,
                  reply.created_by_name,
                  reply.created_by_id.toString(),
                  reply.avatar,
                  reply.created_at,
                  mentions));
            }
            final newComment = Comment(
                comment.data.id,
                comment.data.description,
                comment.data.created_by_name,
                comment.data.created_by_id.toString(),
                comment.data.avatar,
                comment.data.created_at,
                commentMentions,
                replies);

            final index = commentList
                .indexWhere((element) => element.id == newComment.id);
            commentList[index] = newComment;
          }
        }
      } else {
        var commentMentions = <Mention>[];
        for (var mention in comment.data.mentioned) {
          commentMentions.add(Mention(mention.id.toString(), mention.name));
        }
        var replies = <Reply>[];
        for (var reply in comment.data.replies) {
          var mentions = <Mention>[];
          for (var mention in reply.mentioned) {
            mentions.add(Mention(mention.id.toString(), mention.name));
          }
          replies.add(Reply(
              reply.reply_id,
              reply.comment_id,
              reply.description,
              reply.created_by_name,
              reply.created_by_id.toString(),
              reply.avatar,
              reply.created_at,
              mentions));
        }
        commentList.insert(
            0,
            Comment(
                comment.data.id,
                comment.data.description,
                comment.data.created_by_name,
                comment.data.created_by_id.toString(),
                comment.data.avatar,
                comment.data.created_at,
                commentMentions,
                replies));
      }

      commentList.refresh();

      // Show success toast
      Get.snackbar(
        translate('success'),
        'Comment posted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } else {
      // Some backends return 23000 when notification inserts fail even if the comment is saved.
      final statusCode = responseData['status_code']?.toString();
      final message = responseData['message'] ?? 'Failed to post comment';

      if (statusCode == '23000') {
        // Treat this as a soft-success: refresh comments and clear inputs to avoid warning popups.
        PAGE = 1;
        await getComments();
        commentController.clear();
        commentId.value = 0;
        mentionList.clear();

        Get.snackbar(
          translate('success'),
          'Comment posted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
        return;
      }

      // Handle real error response with a clear failure message instead of warning
      Get.snackbar(
        translate('error'),
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  bool hasComment(int id) {
    for (var oldComment in commentList) {
      if (oldComment.id == id) {
        return true;
      }
    }
    return false;
  }

  Future<void> deleteComment(String id) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(
        await preferences.getAppUrl() + Constant.DELETE_COMMENT_URL + "/$id");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black);
    final response = await http.get(uri, headers: headers);
    log(response.body.toString());

    final responseData = json.decode(response.body);

    EasyLoading.dismiss(animation: true);

    if (response.statusCode == 200) {
      PAGE = 1;
      getComments();
    } else {
      var errorMessage = responseData['message'];
      print(errorMessage);
      throw errorMessage;
    }
  }

  Future<void> deleteReply(String id) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(
        await preferences.getAppUrl() + Constant.DELETE_REPLY_URL + "/$id");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black);
    final response = await http.get(uri, headers: headers);
    log(response.body.toString());

    final responseData = json.decode(response.body);

    EasyLoading.dismiss(animation: true);

    if (response.statusCode == 200) {
      PAGE = 1;
      getComments();
    } else {
      var errorMessage = responseData['message'];
      print(errorMessage);
      throw errorMessage;
    }
  }

  void removeMember(Member member) {
    mentionList.remove(member);
  }
}
