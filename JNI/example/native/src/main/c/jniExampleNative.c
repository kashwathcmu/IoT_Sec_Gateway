#include <stdio.h>
#include <stdlib.h>
#include <jni.h>

JNIEXPORT void JNICALL Java_slab_helloworld_NativeStuff_helloNative(JNIEnv *env, jobject obj) {
  printf("Hello from C!\n");
}

JNIEXPORT jint JNICALL Java_slab_helloworld_NativeStuff_add(JNIEnv *env, jobject obj, jint in_a, jint in_b){
  int res = in_a+in_b;
  return res;
}
