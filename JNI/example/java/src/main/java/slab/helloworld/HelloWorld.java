package slab.helloworld;

import slab.helloworld.NativeStuff;

public class HelloWorld {
	public static void main(String args[]){
		System.out.println("Hello World, Maven");

		NativeStuff cfunc = new NativeStuff();

		//new NativeStuff().helloNative();
		cfunc.helloNative();

		System.out.println("Adding result = " + cfunc.add(1,2));

	}
}
