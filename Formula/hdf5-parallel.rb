class Hdf5Parallel < Formula
  # Adapted from official hdf5 formula to use MPI I/O
  desc "File format designed to store large amounts of data (parallel version)"
  homepage "https://www.hdfgroup.org/HDF5"
  url "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.bz2"
  version "1.14.3"
  sha256 "9425f224ed75d1280bb46d6f26923dd938f9040e7eaebf57e66ec7357c08f917"
  license "BSD-3-Clause"
  version_scheme 1

  bottle do
    root_url "http://forge.abinit.org/homebrew"
    sha256 cellar: :any, arm64_sonoma: "50faf8e52f2e15ad59e4ad537d4552a1a99e3583f74a257780489500d04a3a7e"
    sha256 cellar: :any, arm64_monterey: "e705924bb580fa3d6f25058f03599f373e92833ac4425b368fdeeb9e8cecfb26"
    sha256 cellar: :any, arm64_ventura: "efd2bfabaa78d255a3fea9b2da25257852a33269fd23e9045417d4ca8df80205"
    sha256 cellar: :any, sonoma: "6e54f197c8af0e2a888de56d5dda37a807974418e13f13e825e42d9f48cf9074"
    sha256 cellar: :any, monterey: "52fd648c9d0f922a77f1c2e5e5ae5bf97318f96376fc796327ab9f74d0c6e69f"
    sha256 cellar: :any, ventura: "32fdcced0d3d2b36a79ee925ce4890192426695581e7ac37775efb65ccb0f6da"
    sha256 cellar: :any, big_sur: "70fe2cbd56c0ec4a0701b5c79e9fb019bb7b3336cd903b2f907e875c0d2a66bc"
    sha256 cellar: :any, catalina: "6e4c97cd91e739dfab1a60cf9337b6052effc94c16f9656bd0cd9896e3c52aee"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "46c13e40e1d53dd2ed892cd2fcc56defca4dd94fde31f4328607875b0
  end

  keg_only "conflict with serial hdf5 and hdf5-mpi packages"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "gcc" # for gfortran
  depends_on "libaec"
  depends_on "open-mpi"

  uses_from_macos "zlib"

  def install

    # Work around incompatibility with new linker (FB13194355)
    # https://github.com/HDFGroup/hdf5/issues/3571
    ENV.append "LDFLAGS", "-Wl,-ld_classic" if DevelopmentTools.clang_build_version >= 1500

    inreplace %w[c++/src/h5c++.in fortran/src/h5fc.in bin/h5cc.in],
              "${libdir}/libhdf5.settings",
              "#{pkgshare}/libhdf5.settings"

    inreplace "src/Makefile.am",
              "settingsdir=$(libdir)",
              "settingsdir=#{pkgshare}"

    if OS.mac?
      system "autoreconf", "--force", "--install", "--verbose"
    else
      system "./autogen.sh"
    end

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-build-mode=production
      --enable-fortran
      --enable-parallel
      --prefix=#{prefix}
      --with-szlib=#{Formula["libaec"].opt_prefix}
      CC=mpicc
      CXX=mpic++
      FC=mpifort
      F77=mpif77
      F90=mpif90
    ]
    args << "--with-zlib=#{Formula["zlib"].opt_prefix}" if OS.linux?

    system "./configure", *args
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include "hdf5.h"
      int main()
      {
        printf("%d.%d.%d\\n", H5_VERS_MAJOR, H5_VERS_MINOR, H5_VERS_RELEASE);
        return 0;
      }
    EOS
    system "#{bin}/h5pcc", "test.c"
    assert_equal version.to_s, shell_output("./a.out").chomp

    (testpath/"test.f90").write <<~EOS
      use hdf5
      integer(hid_t) :: f, dspace, dset
      integer(hsize_t), dimension(2) :: dims = [2, 2]
      integer :: error = 0, major, minor, rel

      call h5open_f (error)
      if (error /= 0) call abort
      call h5fcreate_f ("test.h5", H5F_ACC_TRUNC_F, f, error)
      if (error /= 0) call abort
      call h5screate_simple_f (2, dims, dspace, error)
      if (error /= 0) call abort
      call h5dcreate_f (f, "data", H5T_NATIVE_INTEGER, dspace, dset, error)
      if (error /= 0) call abort
      call h5dclose_f (dset, error)
      if (error /= 0) call abort
      call h5sclose_f (dspace, error)
      if (error /= 0) call abort
      call h5fclose_f (f, error)
      if (error /= 0) call abort
      call h5close_f (error)
      if (error /= 0) call abort
      CALL h5get_libversion_f (major, minor, rel, error)
      if (error /= 0) call abort
      write (*,"(I0,'.',I0,'.',I0)") major, minor, rel
      end
    EOS
    system "#{bin}/h5pfc", "test.f90"
    assert_equal version.to_s, shell_output("./a.out").chomp
  end
end
