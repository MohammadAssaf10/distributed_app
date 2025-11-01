#Flutter

generate:
	dart run build_runner build --delete-conflicting-outputs

buildApp:
	flutter clean
	flutter build apk --release

buildAppBundle:
	flutter clean
	flutter build appbundle --release

runRelease:
	flutter clean
	flutter run --release

runProfile:
	flutter clean
	flutter run_profile

dartFix:
	dart fix --dry-run

updatePackages:
	flutter pub upgrade --major-versions

generateNativeSplash:
	dart run flutter_native_splash:create --path=flutter_native_splash.yaml

generateKeyStore:
	keytool -genkey -v -keystore C:\Users\Mohammad\Desktop\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

cleanProject:
	flutter clean
	cd ios && pod deintegrate

resetProject:
	flutter clean
	cd ios && pod deintegrate
	flutter pub get
	flutter pub upgrade
	cd ios && pod install --repo-update

buildDevelopmentAndDistributed:
	./build_and_distribute_android.sh development apk com.example.distributed_app.dev "First APK Release"

buildStagingAndDistributed:
	./build_and_distribute_android.sh staging apk com.example.distributed_app.staging "First APK Release"

#Git

#make commit_and_push <commit_message> branch_name=branch_name
commitAndPush:
	git add .
	git commit -m "$(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))"
	git push origin $(branchName)

pushBranch:
	git push origin $(word 2, $(MAKECMDGOALS))

#Checkout the main branch.
#Merge the source_branch branch into target_branch.
#Push the merged main branch to the remote.
# make merge_branches target_branch=main source_branch=feature/xy
mergeBranches:
	git checkout $(targetBranch)
	git pull origin $(targetBranch)
	git merge $(sourceBranch)
	git push origin $(targetBranch)

createBranch:
	git branch $(word 2, $(MAKECMDGOALS))

deleteLocalBranch:
	git branch -D $(word 2, $(MAKECMDGOALS))

deleteRemoteBranch:
	git push origin --delete $(word 2, $(MAKECMDGOALS))

deleteBranchLocallyAndRemotely:
	git branch -D $(word 2, $(MAKECMDGOALS)) && git push origin --delete $(word 2, $(MAKECMDGOALS))
