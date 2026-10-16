import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  const Failure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  List<Object?> get props => [message, statusCode];
}

sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Ok<T>;
  T? get value => this is Ok<T> ? (this as Ok<T>).data : null;
  Failure? get failure => this is Err<T> ? (this as Err<T>).error : null;
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final Failure error;
}
