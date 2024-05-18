class NetcdfFortranParallel < Formula
  # Adapted from official netcdf-fortran formula to use MPI I/O
  desc "Fortran libraries and utilities for NetCDF (parallel version)"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz"
  sha256 "b50b0c72b8b16b140201a020936aa8aeda5c79cf265c55160986cd637807a37a"
  license "NetCDF"

  bottle do
    root_url "http://forge.abinit.org/homebrew"
    sha256 cellar: :any, arm64_sonoma: "88e761cbe2f3826e95c63299e26f9c2485bfe96870159ae4def8db6374f566be"
    sha256 cellar: :any, arm64_monterey: "4c33a391ee533104f3446b5ee34adfd1ea8e3e212ef088c94cd537316e995e72"
    sha256 cellar: :any, arm64_ventura: "12fe4a39f729875c43939d6f6131db82d19c0262d9a25fbdf1ca56f9512fd7ce"
    sha256 cellar: :any, sonoma: "69660ed461a60403c08f0117d5a89de02d443b64ac045269e645f9e9fe814c21"
    sha256 cellar: :any, monterey: "93c63b9205b8859c56f916e668334a4f49a27eb512fa36a0814d9b2d0d7ea330"
    sha256 cellar: :any, catalina: "dfebdbd585b53feed39814d44b7c44bf34acf47ba74f785d0b2bec253fa42b02"
    sha256 cellar: :any, big_sur: "ef7226fcff9a50acdb635b92d8c7970ceb78f72386768568531e68318408bdf1"
    sha256 cellar: :any, ventura: "f026c6a2382e6d7f4111c48a50b19aded6785e4a2f342bb443cb9871cbd52354"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "cf5e3909b9e0d89d108a2a2abcc068f9c7023e370febdeb1aa27e9b7c
  end

  keg_only "conflict with serial netcdf-fortran packages"

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "hdf5-parallel"
  depends_on "netcdf-parallel"

  def install

   args = std_cmake_args + %w[-DCMAKE_Fortran_COMPILER=mpifort
                              -DCMAKE_C_COMPILER=mpicc
                              -DBUILD_TESTING=OFF
                              -DENABLE_TESTS=OFF
                              -DENABLE_DOXYGEN=OFF]

    # Fixes wrong detection of netcdf-parallel
    args << "-DNETCDF_ROOT=#{Formula["netcdf-parallel"].opt_prefix}"

    system "cmake", "-S", ".", "-B", "build_shared", *args, "-DBUILD_SHARED_LIBS=ON"
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"

    system "cmake", "-S", ".", "-B", "build_static", *args, "-DBUILD_SHARED_LIBS=OFF"
    system "cmake", "--build", "build_static"
    lib.install "build_static/fortran/libnetcdff.a"

  end

  test do
    (testpath/"test.f90").write <<~EOS
      program test
        use netcdf
        integer :: ncid, varid, dimids(2)
        integer :: dat(2,2) = reshape([1, 2, 3, 4], [2, 2])
        call check( nf90_create("test.nc", NF90_CLOBBER, ncid) )
        call check( nf90_def_dim(ncid, "x", 2, dimids(2)) )
        call check( nf90_def_dim(ncid, "y", 2, dimids(1)) )
        call check( nf90_def_var(ncid, "data", NF90_INT, dimids, varid) )
        call check( nf90_enddef(ncid) )
        call check( nf90_put_var(ncid, varid, dat) )
        call check( nf90_close(ncid) )
      contains
        subroutine check(status)
          integer, intent(in) :: status
          if (status /= nf90_noerr) call abort
        end subroutine check
      end program test
    EOS
    system "gfortran", "test.f90", "-L#{lib}", "-I#{include}", "-lnetcdff",
                       "-o", "testf"
    system "./testf"
  end
end
