/*
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"

	"github.com/go-logr/logr"
	networkingv1beta1 "k8s.io/api/networking/v1beta1"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

const (
	syncFromLabelKey = "ingress-rules-syncer.x-k8s.io/sync-from"
)

// IngressReconciler reconciles a Ingress object
type IngressReconciler struct {
	client.Client
	Log logr.Logger
}

//+kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
//
// If an Ingress has a label 'ingress-rules-syncer.x-k8s.io/sync-from', the value of that
// label will be used as the name of the Ingress resource to source 'rules' from.
// These will be copied from the referenced/named Ingress resource.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.7.0/pkg/reconcile
func (r *IngressReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.WithValues("ingress", req.NamespacedName)

	var ing networkingv1beta1.Ingress
	if err := r.Client.Get(ctx, req.NamespacedName, &ing); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Base case where an Ingress does NOT have a 'sync-from' label
	if ing.Labels == nil || ing.Labels[syncFromLabelKey] == "" {
		log.V(4).Info("no sync-from label - skipping syncing")
		return ctrl.Result{}, nil
	}

	syncFromName := ing.Labels[syncFromLabelKey]
	// Explicitly avoid creating infinite loops if an ingress references itself
	if syncFromName == req.Name {
		log.V(4).Info("ingress has sync-from label referencing itself - skipping syncing")
		return ctrl.Result{}, nil
	}

	var syncFrom networkingv1beta1.Ingress
	if err := r.Client.Get(ctx, types.NamespacedName{
		Namespace: req.Namespace,
		Name:      syncFromName,
	}, &syncFrom); err != nil {
		log.Error(err, "looking up referenced sync-from ingress")
		// ignore not found errors as the mapping function will re-enqueue this
		// resource if this named resource is created again in future.
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// overwrite the `rules` on the ingress were are syncing 1:1
	ing.Spec.Rules = syncFrom.Spec.Rules

	if err := r.Client.Update(ctx, &ing); err != nil {
		log.Error(err, "updating rules")
		return ctrl.Result{}, err
	}

	log.Info("updated ingress rules", "rules", ing.Spec.Rules)

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *IngressReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&networkingv1beta1.Ingress{}).
		Watches(&source.Kind{Type: &networkingv1beta1.Ingress{}}, handler.EnqueueRequestsFromMapFunc(r.mapIngressesThatReferenceIngress)).
		Complete(r)
}

// mapIngressesThatReferenceIngress will return a list of reconcile.Request for the given
// Ingress resource by querying the list of ALL Ingress resources in the same namespace
// and returning the namespace/name of any that have 'ingress-rules-syncer.x-k8s.io/sync-from: "object.name"',
// where object.name is the 'metadata.name' of the 'object' passed in.
func (r *IngressReconciler) mapIngressesThatReferenceIngress(object client.Object) []reconcile.Request {
	ctx := context.Background()

	var ingressList networkingv1beta1.IngressList
	if err := r.Client.List(ctx, &ingressList,
		client.InNamespace(object.GetNamespace()),
		client.MatchingLabels{syncFromLabelKey: object.GetName()},
	); err != nil {
		r.Log.Error(err, "listing ingresses")
		return nil
	}

	var reqs []reconcile.Request
	for _, toSync := range ingressList.Items {
		// If a user misconfigures their Ingress to points to itself, do NOT sync it
		// to avoid an endless loop.
		if toSync.Name == object.GetName() {
			continue
		}

		reqs = append(reqs, reconcile.Request{
			NamespacedName: types.NamespacedName{
				Namespace: toSync.Namespace,
				Name:      toSync.Name,
			},
		})
	}

	return reqs
}
