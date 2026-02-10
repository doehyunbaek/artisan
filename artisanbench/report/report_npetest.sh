docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
git clone https://github.com/kupl/NPETestArtifact

python3 -m pip install pandas matplotlib matplotlib-venn

cd NPETestArtifact/result
curl -o evosuite_result.zip "https://zenodo.org/records/13738493/files/evosuite_opt_result.zip?download=1"
unzip evosuite_result.zip
mkdir evosuite
mv evosuite_opt_result evosuite
curl -o npetest_result.zip "https://zenodo.org/records/13738493/files/npetest_result.zip?download=1"
unzip npetest_result.zip
mkdir npetest
mv npetest_result npetest

cd /workspace/NPETestArtifact && ./scripts/get_main_results.sh

echo "==========Table 2 Discrepancy==========="
cat /workspace/NPETestArtifact/result/main_result.txt

echo "==========Table 3 Discrepancy==========="
echo "NPETest 5 minute results"
cat /workspace/NPETestArtifact/result/npetest_result.csv  | tail -n 1
EOF
