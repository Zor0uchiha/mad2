import 'package:hive/hive.dart';
import '../../data/models/book_model.dart';
import '../../data/models/bookmark_model.dart';
import '../../data/models/collection_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/reading_goal_model.dart';
import '../../data/models/reading_list_model.dart';
import '../../data/models/reading_progress_model.dart';
import '../../data/models/review_model.dart';
import '../../data/models/user_model.dart';

class BookModelAdapter extends TypeAdapter<BookModel> {
  @override
  final int typeId = 0;

  @override
  BookModel read(BinaryReader reader) {
    return BookModel(
      id: reader.readString(),
      title: reader.readString(),
      author: reader.readString(),
      description: reader.read(),
      coverPath: reader.read(),
      filePath: reader.read(),
      format: BookFormat.values[reader.readInt()],
      pageCount: reader.readInt(),
      currentPage: reader.readInt(),
      progress: reader.readDouble(),
      tags: reader.readList().cast<String>(),
      isFavorite: reader.readBool(),
      lastOpenedAt: reader.read(),
      createdAt: reader.read(),
      updatedAt: reader.read(),
      isbn: reader.read(),
      publisher: reader.read(),
      language: reader.read(),
      publishedDate: reader.read(),
      collectionIds: reader.readList().cast<String>(),
      onlineBookId: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.author);
    writer.write(obj.description);
    writer.write(obj.coverPath);
    writer.write(obj.filePath);
    writer.writeInt(obj.format.index);
    writer.writeInt(obj.pageCount);
    writer.writeInt(obj.currentPage);
    writer.writeDouble(obj.progress);
    writer.writeList(obj.tags);
    writer.writeBool(obj.isFavorite);
    writer.write(obj.lastOpenedAt);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
    writer.write(obj.isbn);
    writer.write(obj.publisher);
    writer.write(obj.language);
    writer.write(obj.publishedDate);
    writer.writeList(obj.collectionIds);
    writer.write(obj.onlineBookId);
  }
}

class BookmarkModelAdapter extends TypeAdapter<BookmarkModel> {
  @override
  final int typeId = 1;

  @override
  BookmarkModel read(BinaryReader reader) {
    return BookmarkModel(
      id: reader.readString(),
      bookId: reader.readString(),
      bookTitle: reader.readString(),
      title: reader.readString(),
      pageIndex: reader.readInt(),
      note: reader.read(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.bookId);
    writer.writeString(obj.bookTitle);
    writer.writeString(obj.title);
    writer.writeInt(obj.pageIndex);
    writer.write(obj.note);
    writer.write(obj.createdAt);
  }
}

class CollectionModelAdapter extends TypeAdapter<CollectionModel> {
  @override
  final int typeId = 2;

  @override
  CollectionModel read(BinaryReader reader) {
    return CollectionModel(
      id: reader.readString(),
      name: reader.readString(),
      description: reader.read(),
      iconName: reader.read(),
      colorValue: reader.readInt(),
      bookIds: reader.readList().cast<String>(),
      sortOrder: reader.readInt(),
      createdAt: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectionModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.write(obj.description);
    writer.write(obj.iconName);
    writer.writeInt(obj.colorValue);
    writer.writeList(obj.bookIds);
    writer.writeInt(obj.sortOrder);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
  }
}

class NoteModelAdapter extends TypeAdapter<NoteModel> {
  @override
  final int typeId = 3;

  @override
  NoteModel read(BinaryReader reader) {
    return NoteModel(
      id: reader.readString(),
      bookId: reader.readString(),
      bookTitle: reader.readString(),
      pageIndex: reader.readInt(),
      text: reader.readString(),
      createdAt: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, NoteModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.bookId);
    writer.writeString(obj.bookTitle);
    writer.writeInt(obj.pageIndex);
    writer.writeString(obj.text);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
  }
}

class ReadingGoalModelAdapter extends TypeAdapter<ReadingGoalModel> {
  @override
  final int typeId = 4;

  @override
  ReadingGoalModel read(BinaryReader reader) {
    return ReadingGoalModel(
      id: reader.readString(),
      targetBooks: reader.readInt(),
      targetPages: reader.readInt(),
      targetMinutes: reader.readInt(),
      startDate: reader.read(),
      endDate: reader.read(),
      currentBooks: reader.readInt(),
      currentPages: reader.readInt(),
      currentMinutes: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingGoalModel obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.targetBooks);
    writer.writeInt(obj.targetPages);
    writer.writeInt(obj.targetMinutes);
    writer.write(obj.startDate);
    writer.write(obj.endDate);
    writer.writeInt(obj.currentBooks);
    writer.writeInt(obj.currentPages);
    writer.writeInt(obj.currentMinutes);
  }
}

class ReadingListModelAdapter extends TypeAdapter<ReadingListModel> {
  @override
  final int typeId = 5;

  @override
  ReadingListModel read(BinaryReader reader) {
    return ReadingListModel(
      id: reader.readString(),
      title: reader.readString(),
      description: reader.read(),
      coverUrl: reader.read(),
      userId: reader.readString(),
      bookIds: reader.readList().cast<String>(),
      isPublic: reader.readBool(),
      sortOrder: reader.readInt(),
      createdAt: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingListModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.write(obj.description);
    writer.write(obj.coverUrl);
    writer.writeString(obj.userId);
    writer.writeList(obj.bookIds);
    writer.writeBool(obj.isPublic);
    writer.writeInt(obj.sortOrder);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
  }
}

class ReadingProgressModelAdapter extends TypeAdapter<ReadingProgressModel> {
  @override
  final int typeId = 6;

  @override
  ReadingProgressModel read(BinaryReader reader) {
    return ReadingProgressModel(
      id: reader.readString(),
      bookId: reader.readString(),
      currentPage: reader.readInt(),
      progressPercentage: reader.readDouble(),
      totalPages: reader.read(),
      lastReadAt: reader.read(),
      readingTimeMinutes: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingProgressModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.bookId);
    writer.writeInt(obj.currentPage);
    writer.writeDouble(obj.progressPercentage);
    writer.write(obj.totalPages);
    writer.write(obj.lastReadAt);
    writer.write(obj.readingTimeMinutes);
  }
}

class ReviewModelAdapter extends TypeAdapter<ReviewModel> {
  @override
  final int typeId = 7;

  @override
  ReviewModel read(BinaryReader reader) {
    return ReviewModel(
      id: reader.readString(),
      userId: reader.readString(),
      userName: reader.readString(),
      bookId: reader.readString(),
      bookTitle: reader.readString(),
      bookCoverUrl: reader.read(),
      rating: reader.readDouble(),
      text: reader.readString(),
      hasSpoiler: reader.readBool(),
      tags: reader.readList().cast<String>(),
      readingDate: reader.read(),
      isPublic: reader.readBool(),
      createdAt: reader.read(),
      updatedAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ReviewModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.userId);
    writer.writeString(obj.userName);
    writer.writeString(obj.bookId);
    writer.writeString(obj.bookTitle);
    writer.write(obj.bookCoverUrl);
    writer.writeDouble(obj.rating);
    writer.writeString(obj.text);
    writer.writeBool(obj.hasSpoiler);
    writer.writeList(obj.tags);
    writer.write(obj.readingDate);
    writer.writeBool(obj.isPublic);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
  }
}

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 8;

  @override
  UserModel read(BinaryReader reader) {
    return UserModel(
      uid: reader.readString(),
      email: reader.readString(),
      displayName: reader.read(),
      photoUrl: reader.read(),
      bio: reader.read(),
      createdAt: reader.read(),
      isAnonymous: reader.readBool(),
      isPublicProfile: reader.readBool(),
      updatedAt: reader.read(),
      booksRead: reader.readInt(),
      readingStreak: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer.writeString(obj.uid);
    writer.writeString(obj.email);
    writer.write(obj.displayName);
    writer.write(obj.photoUrl);
    writer.write(obj.bio);
    writer.write(obj.createdAt);
    writer.writeBool(obj.isAnonymous);
    writer.writeBool(obj.isPublicProfile);
    writer.write(obj.updatedAt);
    writer.writeInt(obj.booksRead);
    writer.writeInt(obj.readingStreak);
  }
}
