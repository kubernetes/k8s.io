package controllers

import (
	"context"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	corev1 "k8s.io/api/core/v1"
	networkingv1beta1 "k8s.io/api/networking/v1beta1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
)

var _ = Describe("Ingress rules syncing controller", func() {
	ctx := context.Background()
	// this variable gets populated in the BeforeEach below before each test
	testNamespace := ""

	Context("When referencing another ingress with a label", func() {
		BeforeEach(func() {
			testNamespace = fmt.Sprintf("ingress-ns-%d", time.Now().UnixNano())
			err := k8sClient.Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: testNamespace}})
			Expect(err).NotTo(HaveOccurred())
		})

		AfterEach(func() {
			err := k8sClient.Delete(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: testNamespace}})
			Expect(err).NotTo(HaveOccurred())
		})

		It("Should fetch rules from the other ingress resource", func() {
			By("Creating a 'parent' Ingress")
			parent := networkingv1beta1.Ingress{
				ObjectMeta: metav1.ObjectMeta{Name: "parent", Namespace: testNamespace},
				Spec: networkingv1beta1.IngressSpec{
					Rules: []networkingv1beta1.IngressRule{newExampleRule("example.com")},
				},
			}
			err := k8sClient.Create(ctx, &parent)
			Expect(err).NotTo(HaveOccurred())

			By("Creating a 'child' Ingress with a label pointing to the parent")
			child := networkingv1beta1.Ingress{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "child",
					Namespace: testNamespace,
					Labels: map[string]string{
						syncFromLabelKey: parent.Name,
					},
				},
				Spec: networkingv1beta1.IngressSpec{
					Rules: []networkingv1beta1.IngressRule{newExampleRule("not.example.com")},
				},
			}
			err = k8sClient.Create(ctx, &child)
			Expect(err).NotTo(HaveOccurred())

			By("Waiting for the child ingress's rules to be set to that of the parent")
			Eventually(func() ([]networkingv1beta1.IngressRule, error) {
				var child networkingv1beta1.Ingress
				if err := k8sClient.Get(ctx, types.NamespacedName{Namespace: testNamespace, Name: "child"}, &child); err != nil {
					return nil, err
				}

				return child.Spec.Rules, nil
			}).Should(Equal(parent.Spec.Rules))
		})

		It("Should update the child ingress when the parent ingress changes", func() {
			By("Creating a 'parent' Ingress")
			parent := networkingv1beta1.Ingress{
				ObjectMeta: metav1.ObjectMeta{Name: "parent", Namespace: testNamespace},
				Spec: networkingv1beta1.IngressSpec{
					Rules: []networkingv1beta1.IngressRule{newExampleRule("example.com")},
				},
			}
			err := k8sClient.Create(ctx, &parent)
			Expect(err).NotTo(HaveOccurred())

			By("Creating a 'child' Ingress with a label pointing to the parent")
			child := networkingv1beta1.Ingress{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "child",
					Namespace: testNamespace,
					Labels: map[string]string{
						syncFromLabelKey: parent.Name,
					},
				},
				Spec: networkingv1beta1.IngressSpec{
					Rules: []networkingv1beta1.IngressRule{newExampleRule("not.example.com")},
				},
			}
			err = k8sClient.Create(ctx, &child)
			Expect(err).NotTo(HaveOccurred())

			By("Waiting for the child ingress's rules to be set to that of the parent")
			Eventually(func() ([]networkingv1beta1.IngressRule, error) {
				var child networkingv1beta1.Ingress
				if err := k8sClient.Get(ctx, types.NamespacedName{Namespace: testNamespace, Name: "child"}, &child); err != nil {
					return nil, err
				}

				return child.Spec.Rules, nil
			}).Should(Equal(parent.Spec.Rules))

			By("Updating the parent ingress")
			parent.Spec.Rules = []networkingv1beta1.IngressRule{newExampleRule("new.example.com")}
			err = k8sClient.Update(ctx, &parent)
			Expect(err).NotTo(HaveOccurred())

			By("Waiting for the child ingress's rules to be set to that of the parent")
			Eventually(func() ([]networkingv1beta1.IngressRule, error) {
				var child networkingv1beta1.Ingress
				if err := k8sClient.Get(ctx, types.NamespacedName{Namespace: testNamespace, Name: "child"}, &child); err != nil {
					return nil, err
				}

				return child.Spec.Rules, nil
			}).Should(Equal(parent.Spec.Rules))
		})
	})
})

func newExampleRule(host string) networkingv1beta1.IngressRule {
	return networkingv1beta1.IngressRule{
		Host: host,
		IngressRuleValue: networkingv1beta1.IngressRuleValue{
			HTTP: &networkingv1beta1.HTTPIngressRuleValue{
				Paths: []networkingv1beta1.HTTPIngressPath{
					{
						Path: "/a",
						Backend: networkingv1beta1.IngressBackend{
							ServiceName: "service-name",
							ServicePort: intstr.FromInt(8080),
						},
					},
				},
			},
		},
	}
}
