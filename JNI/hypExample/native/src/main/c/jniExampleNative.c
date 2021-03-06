#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include <jni.h>

#include "include/uhcall.h"
#include "include/uhcalltest.h"


__attribute__((aligned(4096))) __attribute__((section(".data"))) uhcalltest_param_t uhcp;

JNIEXPORT void JNICALL Java_slab_helloworld_NativeStuff_helloNative(JNIEnv *env, jobject obj) {
  printf("Hello from C!\n");
}

JNIEXPORT jint JNICALL Java_slab_helloworld_NativeStuff_add(JNIEnv *env, jobject obj, jint in_a, jint in_b){
  int res = in_a+in_b;
  printf("%d + %d = %d\n", in_a, in_b, res);
  return res;
}

JNIEXPORT jbyteArray JNICALL Java_slab_helloworld_NativeStuff_hypcall(JNIEnv *env, jobject obj, jbyteArray in, jint len){
  uhcalltest_param_t *ptr_uhctp = (uhcalltest_param_t *)&uhcp;
  int i;

  jsize num_bytes = (*env)->GetArrayLength(env, in);
  jbyte* b=(*env)->GetByteArrayElements(env, in, 0);
  memcpy(&ptr_uhctp->in, b, len);

  if(!uhcall(UAPP_UHCALLTEST_FUNCTION_TEST, ptr_uhctp, sizeof(uhcalltest_param_t)))
 	   printf("hypercall FAILED\n");
    else
 	   printf("hypercall SUCCESS\n");

  jbyteArray returnArray = (*env)->NewByteArray(env, len);
  (*env)->SetByteArrayRegion(env, returnArray, 0, len, (const jbyte*)ptr_uhctp->out);
  return returnArray;
}
