class NetcdfParallel < Formula
  # Adapted from official netcdf formula to use MPI I/O
  desc "Libraries and data formats for array-oriented scientific data (parallel version)"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz"
  sha256 "cf11babbbdb9963f09f55079e0b019f6d0371f52f8e1264a5ba8e9fdab1a6c48"
  license "BSD-3-Clause"

  bottle do
    root_url "http://forge.abinit.org/homebrew"
    sha256 cellar: :any, arm64_sonoma: "2fd26dbf3127b44df312fea26ebb49812c6bceb3004ce08fb9892608b66e65a8"
    sha256 cellar: :any, arm64_monterey: "76f961b7cbb9f246e81e73b868497e1fc6c1a2c6d29bb005ab3bdb63684c2d1e"
    sha256 cellar: :any, arm64_ventura: "470c818028479c2563b05d322aecfb6a16dbb17b8b645571fcae7fc9b82eeef1"
    sha256 cellar: :any, sonoma: "72eb608b2ecc829a2b0f1bc73c8d43e1e1fdd10ba5cf7fe3a0c436faed32fa0a"
    sha256 cellar: :any, monterey: "386c27d5a02a900f8693b5043992359a710efa70d770ff6180f7b33b321cbb85"
    sha256 cellar: :any, ventura: "37b48a22899266e3164fbc7b7f423a52fd3639477dd6afad75d3501dba7297d3"
    sha256 cellar: :any, big_sur: "914d46cd4aa81e1876df008681fd87a252185d8a6c42d6815f81b337bca9170f"
    sha256 cellar: :any, catalina: "ec4c6105a88ea7b2465f8dc7a198909d928e1362e68e96c25c68a08848a6267f"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "99e8e252524ade6f23a6f786c2aed877d9d22bc577cf73252cf7890ca
  end

  keg_only "conflict with serial netcdf and pnetcdf packages"

  depends_on "cmake" => :build
  depends_on "open-mpi"
  depends_on "hdf5-parallel"

  uses_from_macos "m4" => :build
  uses_from_macos "bzip2"
  uses_from_macos "curl"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  def install

    args = std_cmake_args + %w[-DCMAKE_C_COMPILER=mpicc
                               -DCMAKE_CXX_COMPILER=mpicxx
                               -DBUILD_TESTING=OFF
                               -DENABLE_TESTS=OFF
                               -DENABLE_NETCDF_4=ON
                               -DENABLE_PARALLEL4=ON
                               -DENABLE_DOXYGEN=OFF]

    # Fixes wrong detection of hdf5-parallel
    args << "-DHDF5_ROOT=#{Formula["hdf5-parallel"].opt_prefix}"

    # Fixes "relocation R_X86_64_PC32 against symbol `stderr@@GLIBC_2.2.5' can not be used" on Linux
    args << "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" if OS.linux?

    system "cmake", "-S", ".", "-B", "build_shared", *args, "-DBUILD_SHARED_LIBS=ON"
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"
    system "cmake", "-S", ".", "-B", "build_static", *args, "-DBUILD_SHARED_LIBS=OFF"
    system "cmake", "--build", "build_static"
    lib.install "build_static/liblib/libnetcdf.a"

  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include "netcdf_meta.h"
      int main()
      {
        printf(NC_VERSION);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-I#{include}", "-lnetcdf",
                   "-o", "test"
    if head?
      assert_match(/^\d+(?:\.\d+)+/, `./test`)
    else
      assert_equal version.to_s, `./test`
    end
  end
end
