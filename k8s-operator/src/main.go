package main

import (
	"fmt"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	//"k8s.io/client-go/tools/clientcm12861286

)

func main() {

	// config, err := rest.InClusterConfig()
	// if err != nil {
	// 	panic(err.Error())
	// }

	config, err := clientcmd.BuildConfigFromFlags("", "/Users/alex/.kube/config")
	if err != nil {
		panic(err.Error())
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

