install_oracle_libraries(){
  echo $HOME
  local build_dir=${1:-}
  echo "Installing oracle libraries"
  mkdir -p $build_dir/oracle
  cd $build_dir/oracle
  local basic_download_url="https://dl.boxcloud.com/d/1/BHi27SEWTSkUlpnOcM3v9GQiebHgLS3i6Kewc4REK1Mtn93S1kEy3vKAtyBFcRfjzZvWvFUBx7XQCTa1pYxw92xGG1nXYf_LxHDTXJoY1xwL2hxoLFmnLc78LN3LEsslA1Ls39LuSRnYitgkmOZ9xEWZDQvsrhtUBJwVfbzhNJxmfj6llgYXqpMDmR9N9Gfk-O9ESMwsIvAf8jMXclkBZc01iPhGnTrjXK2Je1SLiHH06oZKiywU3nmxyScDHInnUmeNO602WPQ7TU8JbErTuT3Ge7IOlRNQ8SRrB5y3x2B3-2lvJsxiZBQ2tZf-cHTFi0gAq_cB3zrodXApFADZTcYHLQQuU9R8baDyoQwiipdeBjyQ00NM92AOyupycg8p6rVTJICr4EDuhdLqnA5_XyQ54V2rUxnklGpZd-Im4-ejU0xRq6CU01NhL9IxUiZ113vG1YcNZxPgTRZ5o0Bduqye5LFVV1OfArRuyO7ZfnZ6CEQu_Fxn1Huz48Op-7J8UuKqt-lSy4qqDkEeYgXvJP_hoKfDsb8lPzQGlHQUrBE8XnLRglm6N6ZNbQynsrwPhPGH8baL8CscBBQKgG2tHyhwCS83IShVC-Hh3-KINOxgEu__cSS2XrqZfrZDxKbx4j4XC8VlGt8_NfD0fe95Z1XFUccp5OJSrPIl9mRCHa1AQLwGh54RTZ8fe0POJedCQRZ4vTdafF20fqdaEc5saLz4e8XyvxX-sahZkpRZVAq6Qp07PSq2S3Vm3Rd8VdxR-QqpcL1Mf-gaqmhN_jmG7yQfp4GdulLgLbEX8N03h_lARx_rYP_A0kmyDZnWdspbHkxKMWr8IQjMHVZm7FeImnSPVdeJj9bPcGekAR4DKQGu9-0FiNI2qoag3h47OY61CwohWSsOBxVj3xFe4MnIKfQS2jcZ5NKpQxlEZri3ZWG-QXRagU7l0f_l4eD_d3M37t1f_ZF6wHb4kpd4883a-2hgmOUjCF5y51OPC7rzFS3fWfhTueS8_soF2oPJr8KhS8Ven_VpNvCBFwb4Of58aXobXlVwMqN-8Dx8g6wNa85eMCqF6YDCOaTWDzfYHYtYlpJyDpw_bVssKgsJFWzbc60C8KXbnbzRkymlDKki-aLxEq48YOzgQDDMZOeTqiDgwW9NGrDY5WaqoU3RS69AN_gQ1Jwdsqc5JK_D83jUT3uMO3rQyvgk/download"
  curl -k "$basic_download_url" --silent --fail --retry 5 --retry-max-time 15 -o instantclient.zip
  echo "Downloaded [$basic_download_url]"
  echo "unzipping libraries"
  unzip instantclient.zip
  mv instantclient_12_2 instantclient
  cd instantclient
  ln -s libclntsh.so.12.1 libclntsh.so
}

list_dependencies() {
  local build_dir="$1"

  cd "$build_dir"
  if $YARN; then
    echo ""
    (yarn ls || true) 2>/dev/null
    echo ""
  else
    (npm ls --depth=0 | tail -n +2 || true) 2>/dev/null
  fi
}

run_if_present() {
  local script_name=${1:-}
  local has_script=$(read_json "$BUILD_DIR/package.json" ".scripts[\"$script_name\"]")
  if [ -n "$has_script" ]; then
    if $YARN; then
      echo "Running $script_name (yarn)"
      yarn run "$script_name"
    else
      echo "Running $script_name"
      npm run "$script_name" --if-present
    fi
  fi
}

yarn_node_modules() {
  local build_dir=${1:-}

  echo "Installing node modules (yarn)"
  cd "$build_dir"
  # according to docs: "Verifies that versions of the package dependencies in the current project’s package.json matches that of yarn’s lock file."
  # however, appears to also check for the presence of deps in node_modules
  # yarn check 1>/dev/null
  if [ "$NODE_ENV" == "production" ] && [ "$NPM_CONFIG_PRODUCTION" == "false" ]; then
    echo ""
    echo "Warning: when NODE_ENV=production, yarn will NOT install any devDependencies"
    echo "  (even if NPM_CONFIG_PRODUCTION is false)"
    echo "  https://yarnpkg.com/en/docs/cli/install#toc-yarn-install-production"
    echo ""
  fi
  yarn install --pure-lockfile --ignore-engines 2>&1
}

npm_node_modules() {
  local build_dir=${1:-}

  if [ -e $build_dir/package.json ]; then
    cd $build_dir

    if [ -e $build_dir/npm-shrinkwrap.json ]; then
      echo "Installing node modules (package.json + shrinkwrap)"
    else
      echo "Installing node modules (package.json)"
    fi
    npm install --unsafe-perm --userconfig $build_dir/.npmrc 2>&1
  else
    echo "Skipping (no package.json)"
  fi
}

npm_rebuild() {
  local build_dir=${1:-}

  if [ -e $build_dir/package.json ]; then
    cd $build_dir
    echo "Rebuilding any native modules"
    npm rebuild --nodedir=$build_dir/.heroku/node 2>&1
    if [ -e $build_dir/npm-shrinkwrap.json ]; then
      echo "Installing any new modules (package.json + shrinkwrap)"
    else
      echo "Installing any new modules (package.json)"
    fi
    npm install --unsafe-perm --userconfig $build_dir/.npmrc 2>&1
  else
    echo "Skipping (no package.json)"
  fi
}
