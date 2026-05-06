# Aggregate ~/.kube/config-files/*.yml into KUBECONFIG. ("N" glob qualifier
# = no error if no match.)
export KUBECONFIG="$HOME/.kube/config"

for file in $HOME/.kube/config-files/*.{yml,yaml}(N); do
    export KUBECONFIG="$file:$KUBECONFIG"
done
