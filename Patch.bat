@echo off
setlocal
set "WF_PATCH_SCRIPT=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$text = [IO.File]::ReadAllText($env:WF_PATCH_SCRIPT); $marker = ':wreckfest_adapter_script'; & ([scriptblock]::Create($text.Substring($text.LastIndexOf($marker) + $marker.Length)))"
set "WF_PATCH_RESULT=%errorlevel%"
echo.
pause
exit /b %WF_PATCH_RESULT%
:wreckfest_adapter_script
$ErrorActionPreference = 'Stop'
$files = [Collections.Generic.List[object]]::new()
$written = [Collections.Generic.List[object]]::new()

function Get-Hash([byte[]]$bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Read-Image([IO.FileStream]$stream) {
    $image = [byte[]]::new([int]$stream.Length)
    $stream.Position = 0
    $read = 0
    while ($read -lt $image.Length) {
        $count = $stream.Read($image, $read, $image.Length - $read)
        if ($count -eq 0) { throw 'Could not read the complete executable.' }
        $read += $count
    }
    return ,$image
}

function Write-Image([IO.FileStream]$stream, [byte[]]$image) {
    $stream.Position = 0
    $stream.Write($image, 0, $image.Length)
    $stream.SetLength($image.Length)
    $stream.Flush($true)
}

try {
    Write-Host 'Wreckfest GPU adapter fix - 1.308438'
    $folder = (Read-Host 'Directory containing Wreckfest.exe or Wreckfest_x64.exe').Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($folder)) { throw 'No directory entered.' }
    $folder = [IO.Path]::GetFullPath($folder)
    if (-not [IO.Directory]::Exists($folder)) { throw 'Directory not found.' }
    Write-Host '1 - Patch'
    Write-Host '2 - Restore'
    $choice = (Read-Host 'Choose 1 or 2').Trim()
    if ($choice -notin '1', '2') { throw 'Choose 1 or 2.' }
    $patch = $choice -eq '1'

    # Embedded byte differences and helper code; no downloads or compiler needed.
    $packed = @'
H4sIAAAAAAACCu196ZPqOLLv/1Jf6bjYxoDdEfNBlveyDTJ4nZh4ATZ4wSxVLAYm5n+/kkwtp0+d7jMxr+e9uVe/CihLKaVSmak0
iLT9178/eYvt6unXp+h1lW3Wq+Ppv1bX1dMvT5PXqqh2i8ZZ7YpT+fQrLwvSmBO5X56mi1NWrvIPwoDnR/zoo4u5OOL6p6EEJJET
ocrp6lAbA54TJYkDCq4TgTxWOTgaDgYCp4OhJmrKaKQpEhSAyAuAl6EqP70P9WCocYrEi1AbDYeaymu8Jkq8Ph6MBjKvcKowlAYD
XR9pMj/ShyqHCcMBHHDyYCACBXL6GDPU8up0fPr1r39/mqzXx9Xp6Vc8IWW13r8SHczDFwSACzA08tbvSwA4BXgDAv8cCspGXJ8L
EZzAzrOWhTJ3uTI0ykN2U9psK++yrX6yDK9cboeXHCpVOlNueSQWC/zyNXluGfwlNYKzirhn+50z5EF9aaXIC/d9vQ4X02vCR7W/
7m32Mil7en+0qF1C5+L+YTSdEPq+PUX7k43pkxrysMq3mD5ynWDhLAndsW+LfV/BdPe4s8+1ROi3W1Yupi2h0/F6KeFv682skgRc
FhIZ958nYVSnNY/2x2uF+a/0bFtT+lAM+y/TO+nfUy7Rvu8R/rWL6bLQ8d+9TNGDf7C/27i/F8Bm0fHn0TPmrxN6CA5o/zosO3pU
SUZHf3l5k28KO/kJffWg24dEqKl+/shegRZgy7eK0sI0A03zQVELAC0FttpEA3B/xy4hVFJnDrUsjsXDYVx18uYntAws/EreuSgf
rgTaqWh/8igINKjgFh9upjxen1yv0MY78KyQeRTHcwYOdBSlHaJdcWizH7rhGG2s3VUDiXZvgP5jL460QdMJCcX5JPje38n8rNb4
Cdc/50Yo5uRoOtre3/TzXE/eVfPbpYIHdnb2Jon9Eh8jQ9m86XNhYEFeXfG7TkQ+BIePPgDERl+G2FbDFgCvwrZ0l7vvOpHRXUUN
NF1bRMPt8tYZJZgEdmcvVVK/E5EYQgUxb2so9BXiDwoZ3FAbiADVR79olR/Id8sGNvU98TkzO3ttwAsg9kLed0rW6OucbcPjUiCx
qFpruI014WzwDHxsm6P+pXwKBP9f4i9/wYEXrE+rVxZiWYh9hFgIfi/EAuve/ush1ppK/84Qy7EQ+x8aYtXZT4dYZ5dv04HCgzev
c9UeRJ3XzWHynXzfeuefGGL/8cvHZ1ryWX00loVPH23/Feafwjfw8HT9llRf3EC7hrWOQ+DxmtfG3R1wXK0GxIxtv9h0Ssd2dkHR
UjafRRzwsiyMh58k7PNaNkUWWO2LzyOOVFW8oy3a2F9wGHHcT3CYXIQfchBHnzmM3Az+ZsYjezm4ow3u+TdceTisdvmfcBoT6Puf
cRoDpoxqBQ397WYzCdKDrTbGYjYo+XrDPeOyszKjaI4OmH4S8/TgwY4upJvNG33W0RsS5kva/6c/SSMc52X55ZswD6yShHkHdMsa
Ft+vTgA/Vt0fhfnkW43jME/XKvq9MM8R/hP0VQgqfmw8GpDoOYC6iY7+HR+fPsK8vdff9dPN+ifCPHbS9l2f2lf6/irMq48vKW8c
sW+Cr8M8DqM775aQlpPP51brB8ugMwaWr1kacv2mT6CDd6trP5KvAAwMDAwMDAwMDAwMDAwMDAwM/8nQI2dsTY+mPnFiVDmaGM9U
cUa32ovBUQOgp72QfSbLG0MApuUz2YCCjo/upr/utqoqscjIZlElArqPVwWxWAcxF1iNJ0/7szJTxJV40vtWDHLTj0LxJGtWow8t
Xh/qqumvCjretV33Ca5cptEDKTfhlBz0HNTO7PWKjNltAPdl6MzXN0fCPCAeB1onB+pqn0tiYQWhMiV7w0AZGJbXV6By1/ZeH4Ly
rury6tz9vLSsemHe8vLKlR7H9ymIxEsTZ15Y9W7K2EN4ykpUDQIr7Mu8Zp1k1ToaIb9wkHLvcyoHgfliqWI0Ift15VqalklC+swn
ePqq6AukvmoXXh3Oe/2+7If7E3ie9lGZgWmlS7itKpRxTSYLVTGckfZ7NG+nxf4uiI0sW43cI3rTJo6Halz/oss7NKxa6Hh7XK8a
pHxaKGoxLV77nHURy7XMWUaRiar4HPb70UKtMe0QY7twfTndBxPQg83K9td1n99fEqmVe/565vkrH9VJGPQv/X5a9CN/jcu4TxUO
pGBS5qS+kJCL+bQVFwR1GLiufLz3xSZX9Wesfw9V3Kbty4begp51p94hrcuHq1Uc55bZZlq6dFPxLu/5ENuOh9ZRCZrUrziQYbvq
rVk2uK1VZg23TI5KnYYS8YKgMTq9Y31gG6vrrAW58qKuc4T/zxw/Q2N/ee2p1km/qSciw3RDRrJO2D9iOweVA0LMA9SYx8lTLTy+
m+vdNq1iBM2io7+NkZ6dOar0W4ysqtWJfBb1O3T7ri73Z94cXX0k5Xq3j6vMqzaNML2lcwI9e0p8WSTj/laWuK+K87DTUYAicSNi
n1zHe+KLFsJrT5bI2rO6tYfH95rZXcb+NAuwfvAY+4feXisR2w9jIgZHYq88FJwypP41Lucq8UF+Lp71mMhyP+vedNzvD0IF9yse
/UTabz7x/LzE/oD54GUZ4HUm6+peWN/xHKaaSnxSqRx/hXWel2Rt6COs84EZWBUXHydcXOQK1PttT4fdvGU42dDV/GZbavfkBDAd
db7xbR3xY1w2cbyg5TMgPzOVy5gfOcNwADWguncav8xjSva+uxjmhetrFPLPTjVqsWmher/0nPOoIOtyD4jvH3O9T20EH/auO3tr
NxJTsG39oGoNr8nomp0Rebo1q4ju/mjWiZBRnYQrB8FHX6WHdQHG5bKmOtb2J32onvUL1W9gXgpiO/UV1FOh4gbS93NNpqUvKlgm
pb2RuAPut4S/g33D962LoV4lUJh1D5joiP/38f+mUAtsgzNY4XiGda22aKa2YKb06M8Uyk3oHZ1C0tRRu8A05xUERo9u6ltcYMwu
94swx3Hhxc7XlacoiUxXpem6FbacLxYQ7QEeJ36pBrFUrLdUY1k7NxRlAyqes1wcl7cjIisU79ndvU/Xdbvaq9XRASJ49lQFwNvs
NS1ct630Vh5bl4UvxsscR9pblExNjvz+q/T6hcI55H+rcHYCyByXhYl1YSKE5dcKKdHexz9dXqE4VUDvaGAaHLW6QmShMW9/4nuW
MLfp7yBTv0Yomna6uKvJQZuuTtMK2Arax/18tX3T0x26C82YUZ2DmB9254ICATyjb/7649gla6M/QBttKnO2ovZziNBI32EjSzIo
lFHlWi7xQwHLY4M7obv9awAkHIuDXj0ifhNJlsU+eDAwMDAwMDAwMDAwMPxPgFLWrXuYzIutfzBlaJRD4O/1VPAP7t06p8b1SFr5
qqfNOD6YD5RmudE3SaxwaWwb2VY+zc3wkJJGGrr72skLdZ3HtCGK/DIz/SbbNOd0K33QNe+4HHjNOx1/mZ+QfL8tPq73n2SzdwPh
USZf+OmekhpY+Ks4D45vjT7lj9I9XpJgDCJI9lgK953Vdr1edPmBHnmjXI22wvM/qj9SDd0BkrrDqssJJ7sOVGtkqGlBOFJ5XKgR
zojkVpK0T4UypXnNdBN4o+B3UwoxZUHaJzfc3tyUWPwJKb/McFk7knJqdZmpkPRUHjmwClL2aXRt09i6u9VwszRaEHPhOY94q6u3
gTtPgB8N+WXo7RcRB+ZbnVvEaeMLITeP5E0eXZuZoRObNkAblrnRCGmQN7mu3JaCp6SGf0tj7/5Ba86LGJGU+yYR5Fuqlc3SVLA9
AQf0R53ejdVdjzD5Ng3Ubcl2ard/QNI6DZLFqcwCzp+flPFZCYVjrD33ZoPjKl5uK0Q1paiT5hpmQnjL+CuWKWwXZpn5hlzjuTbL
nX+PNe+C68VYtVq3Tk7uHJzcOs0WM150ayXLsVwL/jrItmG9ENImG6BT8uZrOy9Lts05wf4ZGza/iK6bWM8Py9q9xcZjfvjY2Smb
5HM+6e+k8hKv2BbY7eAQr4mSsw3+DN69VqU9P/JtVUQUMqSeO2xSQ+cS3OJE/Kfb3D1nWx/rX9vkW/mYGzzdFuYJXS2Uz/TV7jBK
Dbu7vEJ99//zG89HLm3xGP+ebd2Nqz6ygzVqmY4fyc+9odZl+bMMDAwMDAwMDAwMDAwMDAwMP43jRGmBM1fUwhBbJCpMIwwMDAwM
DAwMDAwMDAwMDAwMDAwM/yRQd6NLkn9YfE2nWXXuj+k22ZylNyw1aL6c/MNcP7Xtrwz+aJkpySM8LAVRtu/a2YVZkUbDein4h+U2
k20+DPyKE+2bcs9pvqV+XArDZjrLh2ns7qZ30YP1tcwGXrOM7ONqpojL6HrO7twuj+3zZOfVCyM8JbF7WkZNnW3l+1JIOSfyLsv5
ocwE7pzX2s4y+HK5bbZp7HHhNrxlQnNZ1tzOnYmtTcaoQDE1/VuO6TN6m+X3caqfH8etpgX3bEFQWOr1nkYen20bbjXv+D/qb2lM
cn49Lo18hOnCIro2qRDe3/t2Lynbhtc8CrFewo0fl00yCLlFJJ/nRiikUVssu/+yLeh3LLOwFE5NVmVFHjVKInhNNnAxLS2XptfY
N3D5zH8K5T+WQ20vmRDWeP6H3Nz0VLSndblp89nAt5fblPLEvD7sQ+bKciMZGBgYGBgYGBgYGBgYGBgYGP5DQS4Fphe1Q+mK5nrk
Ru51cdcFd+ne1/OZ6yGmIwYGBgYGBgYGBgYGBgYGBgYGBgaGNzz945e/P3mL7erp16fodZVt1qvj6f9cR+J/ra6rp1+eJq9VUe0W
jbPaFafy6VdhMOBG46Hwy9N0ccrKVf6JMOAHgvTRxVwccf2TNFYGcAhkYTiAYDQGmqJLo7EijocKL8oaJ49EBQoiuXUkz491fSRA
dQg0KMkqVKSh8vQ+1BtDXVHwaNpI1nlhMB4AKPOqOuB1TgADjdNUzEUaSMpwJAAR14+5sTyAmjTkgaLrnIYZanl1Oj79+te/P03W
6+Pq9PQr98uTslrvX4ke5uEL6jJxuxup0nurOh+Jlf/sNnNF2YjrcyGCE9h51rJQ5i5XhkZ5yG5Km23lXbbVT5bhlcvt8JJDpUpn
yi2PxGKBX74mzy2Dv6RGcFYR92y/c1Zfx+0KvorDA7foTRa5cam3O9+4PidccsNlbakdXv0lofvH2VY2IKG7s9GZW4ww3ZSH21e0
tzB9PdguPXAi9P4qPXFWhen6LVss/dc9psf29SAbR0LPdsaw69+NdyT9/fV44UHaf+IpuP+Li8cXOeOOxqJ84DJVlHOD0ttprXEL
gfTfyuex/5oQ/oMM0w8P/hWXvPGv/ZT0R6+7xQmeCR2e8xNnn8n8nofCHYn7a0fP3+ir6F2+y7iTn9Dljh5sm3rxTPSl/YHlFORj
Y6dWYgGFv8Mo+CBNAbAK4IBCRAC+ktukbmZFdw9g7vmy/HAT5e2oey/e7nRKYXwwhAVqj+DjBhwWSMh9hLUv3e79+DczoPUbLyjB
3G+wf2iTylIOtBUEE3ApDm0GgA0ucFBr8Nu+LQKXdtm6wJomCQh/7OXFNEvArKA85ZLc6/U3UmhkARfeTyyNc26EYk71eTz00INT
p8+vjEO193GPWnB7hptuPABennF/57L5rhO9TTEcvvUBvqJ5sFBaq9BAUnHk/svVd4uajO6Cc2bQe9gCYHb62kDJAS72BwBH8/a3
ItK8fIB4RfENei9p8WFlEbZdfn+hF8pX8rW6PPM1PUDk8U0gI3zaCTh2nSw7+VI+7XFPXHI73QnckXs9F2rhgOfCxPI9R+Br+Rxy
D2tDrsmFAsTegDxUqsW9cX93C76UD/3LeeV/+QsOvGB9Wr2yEMtC7Pch1v7dEGv93wixeOmDf2OIldQvQuwRL24WYr8Msa76PzDE
Amrvnwqx1XCQbvM2R29e230koNeNPdv1d/LB33o3DrHk4/zbZ1pBGI5H49Hnj7Z/+teJjxAPHEWF3HOL2lPRblwHveLyGHK43JLy
0fFx+YbLZ0TKLSn3BAHTLVKWnFSFbTXAdNofOrkKbzNS3pPyt1OlX0sGoz+c6jdnIeBhka4dYQ+qQnv+QosDSRpLw/Enzn0eiFNE
nptZfOY2mh5iCM5oY4PvOEi8NPwJDo4d/ZADJ3ye3UjXyJ30v+ltNHj8I+75N1x5OKx2+Z9wphXo+59xpgWmjGoFDf3tZjMJ0oOt
NsZiNij5esM947KzMqNojg6YfhLz9ODBji6km80bfdbRG/uQCCXt/0fzCTR8xjFmhoKA8vGADnrmx/HEKmBrTZzHwyF+e3Gd9h4y
tU9l0jT5iAef+iTfahzi1av86EyjfQ4ov6138AceoObfzYVYpnsQM3n9+IGYZkuifPDv2GBwdn6zMruTJn0YifKuJPDV3Qap9uDw
9vZwiBq5j7PSW/v2+06PSP3+QImH0t2Pob5wc8JNBfQBGvSs9dCX9h5b8QkW/OhMd8sGNo3uD32/f/J4O/xCPgYGBgYGBgYGBgYG
BgYGBgaG/xRoN3sOUTG3Gs1WyjDg03hmCUfbquV+X7aK1VUk21Qz66jMksu16h+sSm7cigciWvdnj63faRmTx5tCvd/29GWBKN8D
nO1J37m1PdomeVyq4lZLtFmQ3SxMv0C/6HjHgioi+lMHHkedWXwoapVz424O0hWlL0O9BT1LaTHf6ULX6AaUNS3Xe8LTqtqwNcmv
Ef1U716yVWYKF20qx4zQmrQp8xM3x2UN8zW4Sud2Ph4nXubq0KoRb6m4f1+2rapf0r5OUHl6kE0pf6nucxwuh8dHWcbt1K4uQm91
bld3c3papctFT3she2iaQI/3qDvG+tG2VO+VU9IpK1YdtBtXq2wfovbKoc2EGkbt8/sYrMytg+tFIlOWYBvpXftAqzwf+mDm5pqt
qeSpyf0ZsaFem7jeohUSpumIJ9wI34TuNxJ9Lhxsc7GSK7tekP1BzDMRCrLnh20aY12JlqVLhC/pm18X6hr6mmW602LQbmagvEPN
kOgG4uSo+vPpZmadvTPZn9RuWC60d/vSndtU9hofY/qJ+M/cOlmJZva5JAaqWNOnPG+wHrAse2wLG/sA3ZR05ZNbB2hjYZ3E2Ddd
YpdWdyuuID7nY12IKyGZmhyieiT+S/rn5pC0s+owwj53AhMyloV1CA11neN5KCerGAwSYKKg4mIwCWJrXdwcP0NDP2un9Zg84Brb
kmvJ2PotRjb1e+uEtGl/hv+7NiwfshE9P1IJpn21kr3fyjisuE+ygYbKhtcNon6Gx3j+coxz/lmP1L6PzXrMV0fJJZxZF4esk2/1
udE7H6AyYh9uOBhUDsCvQMF+uamo7zVk7RDfW3Z2r+bFvZ1sLaJ3P4k32AYtOX7jU6dB0ZWp/UDw0KkqFjNSX4kB9ZtJElMhVTEA
j/rNo37T1cf0Ac24fv+o3z/qs0f98VF/fNTTX7C62DCn2+XzhBzPxMdxHx9fujZnfUZ1Vnlz6KNuHahkHSQP+0RlBqaVRfwfOqSe
lMvulxC87nzsf7xrG3i+2LZuZ9uWriGOrEu/W5f04eR9wvdIL9AmtjG7B55j20TEppF1SarHWsJx1NtTucw+L8bLFeyRtdxO18T1
lYFNdKzO1N5MuRviKbDVSu0V5V2rsfyawqtq49qazyt1E9hayWkctaE+6Y+JXA5eW8UomPdInP4Dn/3aHwbIxW1N7E/Tt/bE91b7
0q3G73HaecXz7+L4eWM/F10cH7c4nhB6pVxNWreOm1PeSnf37l7dSr7aVXhEs6R5NbStnd0UfF4xj8fOTs5xURD/8+rAtfD4h5nF
hTp5wDymVdQ3wV3gtnbUVv2HHbDsN2emkvhl6K1Z4nV1dm2382Myv0U3P68h8iIAPvvrSuXx+ktxbCD2rZz75tO5xSx2lYg29Bdw
davZNpWN15Mz9qMW+x7s01hHaS2hcWB/Gf92/G/0uyf+GT7TtUBigzRBE7vd22T+JhLpMaLHJ3pc0OM1PW7psT+zppjzFCqWOaKL
y3S8UXtT22L6qohTCM5H2MdRupI8rQ72eH1y4QbhZWUrao2QNaXer9xNzXBarIfWujzj9lAdJ5pmVdrzDEH68Hd8Ys3zrdLbd+1h
coHVm6zazKkXtB0eZyLeM2xfzRyImfkC2p7QHtUC7DlXI2MAx8brAPjw1UaJqrjazJoDVPh43DK3eQ7rphWh9AwR/U0qV8/gAouG
/tZkokvhPPSA9WtZpF3WtVN0q5CAVkiuVqy757xnx92rak1V0DuauB6OWqffchG2JdqkB+gFrfE+H128OCiZgr54WaCiJ/hYpspC
h84W8eqdZ/vitNJCe5NvbgmZ7VD72hV/TGbJ6dXStk52K+2q562pr+P1gWMO9sXp8XlSwN6axOCp9qxyEJgvVst7VtFrMf2S9q/x
i0Hj1cUZPTvd5ysJFZHkss+hDAwMDAwMDAwMDP+xUMq6dQ+TebH1D6YMjXII/L2eCv7BvVvn1LgeP/Zf0d3XTl6oyW0aDZUUf7XN
jfDm7+zLMrjyi+gjB89XPW3G8UEQh022a97b0gdNtB90JFzJAxfe6W/9JySTe+s3Wb3/JKu+GwiPMv0eRvYmVPINFEgf+Ymf8klp
Hc23zCC5mAh8ZO5H6/Wi26ry3ltaqMTfnzUVvSV4T0ii4QcmBenR5SuSXZ4paabMAs6f+9HzeYYm8zCAzy/PZ0s7vtwUmgmJv7M2
1xDP8ZbxVzzPsF2YZeYbcp1HfLPc+fdY8y64XoxVq3Xr5OTOwcmt02wx40W3VrJckG8L/jrItmG9ENImG6BTEvllZvrkQSNZsm3O
SWwPY8PGNrhuYrMQPP26T6Nrm8aW4MFhmxrvaam/97BpYkCaL/rIH90so4cC4JumwDnbPq4c8KgVqBbfrlywzfSyNP1TSvey6FUN
NMP/g34YrbZ+lRKFa0WF6fuuf/nIB4WthXsNiCRw2LznlpK06y6/9CPf9FO+7Uc+aWdwup3wyBe1VdBlm5NsYzKRTp57tnU3rvo5
XVeLIQJxqh+BzvsLoGQcdukYhAnQ6B0QtRyLkINIAuoOeAloW8iD0sLTtKb+ESj1ZokA4g0RQNfnyVxQe4JHzXUS11bhrUtGJWWa
li+oELVHBSINwIDIoemYle4WWvvYC+zTvHHi6hXxJdqfSkJzej2iP5Uj+tKg+7Cf2uq4DKm+OrcmlJbmxxYxfnslW4se4adKNW4U
kvKClM0AlyG02jc/scjC0IhGlUL57E+bpdECPxryy6BslqbSZIWiL3fhKRDKwxIpE2yLQ74NzTT2vaXg80sjtJKI9AvAfKtzizht
fCHkAtO+JJy+SU2bPLzlnYbjxCHHayuNvAv2N+sxNgjwGlgO7E03DoveDAwMDAwMDAwMDAwMDAwM/+8gGdYYddcoJ6jfdDtrhqL2
gt/df2NgYGBgYGBgYGBgYGBgYGBgYGBg+N8KBIBCMjlBAsn1fhbJ52t1QPI7LXJ/zoA8pZiUN6TskrJ6IvlwM1KeggiTLL0FYE/K
XT7chpRfoMW0y8DAwMDAwMDAwMDAwMDAwMDAwPC/AFp3/Tu53tr6mk6v+ibXGP+ADsnj3uiDfJSCXI+9Rj98EI80HZSnJVSENLbv
i0g+T2fZ1anBzjLCcyLIm0U03E1neRhqyWkCsyIb+OVyi1+GfE7n3G4VhXf7LvVUtJeS2LunEV8tzU2xMvjjcufK9iC8LevDPRHK
ZhnpdyfiD8nAvmSCvM0hXy8FboT7nZxdcrVvyimJhod0G95zPSXX1x+Wgijbd+3swoyMUVjqlct2mK7RJ+G9j2Ptfnqcu1WLHqxA
YUEgZUJY57F9yM1Nxx8+6rfhNcdzy41wE5iYvm2OaZQ32f29L31NybXT5D4LA79JtVBMI4/Pjeay3FybfBseLaP7j3VYZlxzzrfy
axpbO8sMDyjy6hTrDNO2SXS9p7OscD7zV9vLT8ghOQOvSbCeF7E/nBbcc1fn3/LY4+g9H0jbur18sg+ZK1tqDAwMDAwMDAwMDAwM
DAwMDAz/kXj6x9/+G1s2DPMcGwEA
'@
    $compressed = [IO.MemoryStream]::new([Convert]::FromBase64String($packed))
    try {
        $gzip = [IO.Compression.GZipStream]::new($compressed, [IO.Compression.CompressionMode]::Decompress)
        try {
            $reader = [IO.StreamReader]::new($gzip)
            try { $profiles = $reader.ReadToEnd() | ConvertFrom-Json }
            finally { $reader.Dispose() }
        } finally { $gzip.Dispose() }
    } finally { $compressed.Dispose() }

    # Lock and validate every present executable before changing either one.
    foreach ($profile in $profiles) {
        $path = Join-Path $folder $profile.Name
        if (-not [IO.File]::Exists($path)) { continue }
        try {
            $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        } catch { throw "Cannot open $($profile.Name). Close the game and check folder permissions." }
        $file = [pscustomobject]@{ Name = $profile.Name; Stream = $stream; Before = $null; After = $null; Hash = $null }
        $files.Add($file)
        if ($stream.Length -ne $profile.OriginalLength -and $stream.Length -ne $profile.PatchedLength) {
            throw "Unsupported $($profile.Name). Expected the supported 1.308438 build. No changes made."
        }
        $file.Before = Read-Image $stream
        $hash = Get-Hash $file.Before
        if ($hash -ne $profile.OriginalHash -and $hash -ne $profile.PatchedHash) {
            throw "Unsupported or modified $($profile.Name). No changes made."
        }
        $file.Hash = if ($patch) { $profile.PatchedHash } else { $profile.OriginalHash }
        if ($hash -eq $file.Hash) { continue }
        $length = if ($patch) { $profile.PatchedLength } else { $profile.OriginalLength }
        $file.After = [byte[]]::new([int]$length)
        [Array]::Copy($file.Before, $file.After, [Math]::Min($file.Before.Length, $file.After.Length))
        foreach ($edit in $profile.Edits) {
            $encoded = if ($patch) { $edit.After } else { $edit.Before }
            $bytes = [Convert]::FromBase64String($encoded)
            $bytes.CopyTo($file.After, [int]$edit.Offset)
        }
        if ($patch) {
            $bytes = [Convert]::FromBase64String($profile.Append)
            $bytes.CopyTo($file.After, [int]$profile.OriginalLength)
        }
        if ((Get-Hash $file.After) -ne $file.Hash) { throw 'Invalid patch data. No changes made.' }
    }
    if ($files.Count -eq 0) { throw 'No Wreckfest executables found.' }

    try {
        foreach ($file in $files) {
            if ($null -eq $file.After) { continue }
            $written.Add($file)
            Write-Image $file.Stream $file.After
            if ((Get-Hash (Read-Image $file.Stream)) -ne $file.Hash) { throw "Could not verify $($file.Name)." }
        }
    } catch {
        $failure = $_.Exception.Message
        $rollbackFailed = [Collections.Generic.List[string]]::new()
        for ($i = $written.Count - 1; $i -ge 0; $i--) {
            $file = $written[$i]
            try {
                Write-Image $file.Stream $file.Before
                if ((Get-Hash (Read-Image $file.Stream)) -ne (Get-Hash $file.Before)) { throw 'Restore failed.' }
            } catch { $rollbackFailed.Add($file.Name) }
        }
        if ($rollbackFailed.Count -gt 0) {
            throw ("Patch operation failed. Could not restore: " + ($rollbackFailed -join ', ') + '. Restore these files from a clean copy.')
        }
        throw "Operation failed; previous files restored. $failure"
    }
    foreach ($file in $files) {
        $result = if ($patch) { 'Patched' } else { 'Original restored' }
        if ($null -eq $file.After) { $result = if ($patch) { 'Already patched' } else { 'Already original' } }
        Write-Host ("{0}: {1}." -f $file.Name, $result)
    }
} catch {
    Write-Host ('Error: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    foreach ($file in $files) { $file.Stream.Dispose() }
}
exit 0
