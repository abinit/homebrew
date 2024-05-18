class Abinit < Formula
  desc "Atomic-scale first-principles simulation software"
  homepage "https://www.abinit.org/"
  url "https://www.abinit.org/sites/default/files/packages/abinit-10.0.5.tar.gz"
  sha256 "07fed4df03ae32178933373b990bbda4431ea836fc7bebec05b17e4267bb7f4e"
  license "GPL-3.0-only"

  bottle do
    root_url "http://forge.abinit.org/homebrew"
    sha256 cellar: :any, arm64_sonoma: "ce0e37b3fef4cf377241d273f5bd9a45a3ec80e6ac5a535dddf90d363c8b399a"
    sha256 cellar: :any, arm64_ventura: "67fafbfa079a12306e3251b37702b9ac96d4267a8f4ac07eb4a7c5535412f1d2"
    sha256 cellar: :any, arm64_monterey: "a5744b1b8f50018abef66e4c88267a92c89163812e0dad411af8c431566ec4fa"
    sha256 cellar: :any, sonoma: "df2d2066d3b4aa81191fd488f140a577e74e544e1f27d541e2826b2720543112"
    sha256 cellar: :any, monterey: "d6dad30672e8fa2ffff1fe17a9a3bccfd0e9c44d354a901a316364b657576d36"
    sha256 cellar: :any, ventura: "4e43e1c012dbebba6bce530b66e00174d5a6bff2a8ccf4be0c5480530600491b"
    sha256 cellar: :any, big_sur: "ead8d6d4209a2c61b5823319b2322e3ed100425195efa8592dd9c113b847e896"
    sha256 cellar: :any, catalina: "1663ca4f30e67904a933a9ed72f0cffb16e58babb6cdc9925cd971f6499eda50"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "fd4953210bd307f5a0523cbfcbc0ed8abe4e9d4809601ce71be36ab77037da42"
  end

  option "without-openmp", "Disable OpenMP multithreading"
  option "without-test", "Skip build-time quick tests (not recommended)"
  option "with-testsuite", "Install script to run full test suite (see: brew test abinit)"

  depends_on "gcc"
  depends_on "libxc"
  depends_on "netcdf-fortran"
  depends_on "open-mpi"
  depends_on "openblas"
  depends_on "fftw" => :recommended
  depends_on "libxml2" => :recommended
  depends_on "scalapack" => :recommended
  depends_on "wannier90" => :recommended
  depends_on "netcdf-fortran-parallel" => :optional

  conflicts_with "abinit8", because: "abinit 9 and abinit 8 share the same executables"

  def install
    ENV.delete "CC"
    ENV.delete "CXX"
    ENV.delete "F77"
    ENV.delete "FC"

    compilers = %w[
      CC=mpicc
      CXX=mpicxx
      FC=mpifort
    ]

    compilers << "FCFLAGS_EXTRA=-fallow-argument-mismatch -Wno-missing-include-dirs"

    # On arm mpicc (clang) does not handle correctly -march and -mtune
    if OS.mac? && Hardware::CPU.arm? 
      inreplace "configure", "-mtune=native -march=native", "-march=native"
      if (DevelopmentTools.clang_build_version < 1500)
        inreplace "configure", "-march=native", ""
      end
    end

    args = %W[
      --prefix=#{prefix}
      --with-mpi=yes
      --enable-mpi-inplace=yes
      --with-optim-flavor=standard
      --enable-zdot-bugfix=yes
      --with-libxc=#{Formula["libxc"].opt_prefix}
    ]

    if build.with? "netcdf-fortran-parallel"
      args << "--with-netcdf=#{Formula["netcdf-parallel"].opt_prefix}"
      args << "--with-netcdf-fortran=#{Formula["netcdf-fortran-parallel"].opt_prefix}"
    else
      args << "--with-netcdf=#{Formula["netcdf"].opt_prefix}"
      args << "--with-netcdf-fortran=#{Formula["netcdf-fortran"].opt_prefix}"
    end

    libs = %w[]

    args << ("--enable-openmp=" + (build.with?("openmp") ? "yes" : "no"))

    if build.with? "scalapack"
      args << "--with-linalg-flavor=netlib"
      libs << "LINALG_LIBS=-L#{Formula["openblas"].opt_lib} -lopenblas " \
              "-L#{Formula["scalapack"].opt_lib} -lscalapack"
    else
      args << "--with-linalg-flavor=none"
      libs << "LINALG_LIBS=-L#{Formula["openblas"].opt_lib} -lopenblas"
    end

    if build.with? "fftw"
      args << "--with-fft-flavor=fftw3"
      libs << "FFTW3_FCFLAGS=-I#{Formula["fftw"].opt_include}"
      libs << "FFTW3_LIBS=-L#{Formula["fftw"].opt_lib} " \
              "-lfftw3_threads -lfftw3 -lfftw3f -lfftw3_mpi -lfftw3f_mpi"
    else
      args << "--with-fft-flavor=goedecker"
    end

    args << "--with-libxml2=#{Formula["libxml2"].opt_prefix}" if build.with? "libxml2"
    args << "--with-hdf5=#{Formula["hdf5-mpi"].opt_prefix}" if build.with? "hdf5-mpi"
    args << "--with-wannier90=#{Formula["wannier90"].opt_prefix}" if build.with? "wannier90"

    system "./configure", *args, *libs, *compilers
    system "make"

    if build.with? "test"
      # Find python executable
      py = `which python3`.size.positive? ? "python3" : "python"
      py.prepend "OMP_NUM_THREADS=1 " if OS.linux? && build.with?("openmp")
      # Execute quick tests
      system "#{py} ./tests/runtests.py built-in fast 2>&1 >make-check.log"
      system "grep", "-A2", "Suite", "make-check.log"
      ohai `grep ", succeeded:" "make-check.log"`.chomp
      prefix.install "make-check.log"
    end

    system "make", "install"

    if build.with? "testsuite"
      # Find python executable
      py = `which python3`.size.positive? ? "python3" : "python"
      py.prepend "OMP_NUM_THREADS=1 " if OS.linux? && build.with?("openmp")
      # Generate test database
      system "#{py} ./tests/runtests.py fast[00] 2>&1 >/dev/null"
      # Test paths
      test_path = share/"tests"
      test_dir = Pathname.new(test_path.to_s)
      # Copy tests directory
      share.install "#{buildpath}/tests"
      # Delete some files
      rm_rf "#{test_path}/config"
      rm_rf "#{test_path}/config.*"
      rm_rf "#{test_path}/configure.*"
      rm_rf "#{test_path}/Makefile.*"
      rm_rf "#{test_path}/autogen.sh"
      rm_rf "#{test_path}/wipeout.sh"
      # Copy some needed files
      test_dir.install "config.h"
      Pathname.new("#{test_path}/runtests.py").chmod 0555
      # Create symlinks to have a fake test environment
      mkdir_p "#{test_path}/src"
      cd "#{test_path}/src"
      ln_s bin.relative_path_from("#{test_path}/src"), "98_main", force: true
      # Create a wrapper to runtests.py script
      test_file = File.new("abinit-runtests", "w")
      test_file.puts "#!/bin/sh"
      ver = revision.zero? ? version.to_s : "#{version}_#{revision}"
      test_file.puts "SHAREDIR=`brew --cellar`\"/#{name}/#{ver}/share\""
      test_file.puts "TESTDIR=${SHAREDIR}\"/tests\""
      test_file.puts "if [ -w \"${TESTDIR}/test_suite.cpkl\" ];then"
      test_file.puts " PYTHONPATH=${SHAREDIR}\":\"${PYTHONPATH} #{py} ${TESTDIR}\"/runtests.py\" -b\"${TESTDIR}\" $@"
      test_file.puts "else"
      test_file.puts " echo \"You dont have write access to \"${TESTDIR}\"! use sudo?\""
      test_file.puts "fi"
      test_file.close
      bin.install "abinit-runtests"
      # Go back into buildpath
      cd buildpath
    end
  end

  def caveats
    unless build.with?("testsuite")
      <<~EOS
        ABINIT test suite is not available because it
        has not been activated at the installation stage.
        Action: install with 'brew install abinit --with-testsuite'.

      EOS
    end
    if OS.linux? && build.with?("openmp")
      <<~EOS
        Note: if, running ABINIT without MPI, you experience
        a 'ompi_mpi_init' error, try setting:
        OMP_NUM_THREADS=1
      EOS
    end
  end

  test do
    system "#{bin}/abinit", "-b"
    if build.with?("testsuite")
      system "#{bin}/abinit-runtests", "--help"
      puts
      puts "The entire ABINIT test suite has been copied into:"
      puts "#{share}/tests"
      puts
      puts "This ABINIT test suite is available"
      puts "thanks to the 'abinit-runtests' script."
      puts "Type 'abinit-runtests --help' to learn more."
      puts "Note that you need write access to #{share}/tests."
    end
  end
end
